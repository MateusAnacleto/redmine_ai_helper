require File.expand_path("../../test_helper", __FILE__)
require "redmine_ai_helper/llm"

class RedmineAiHelper::LlmTest < ActiveSupport::TestCase
  fixtures :projects, :issues, :issue_statuses, :trackers, :enumerations, :users, :issue_categories, :versions, :custom_fields, :custom_values, :groups_users, :members, :member_roles, :roles, :user_preferences, :wikis, :wiki_pages, :wiki_contents

  context "RedmineAiHelper::Llm" do
    setup do
      AiHelperConversation.delete_all
      @params = {
        access_token: "test_access_token",
        uri_base: "http://example.com",
        organization_id: "test_org_id",
      }
      @openai_mock = DummyOpenAIClientForLlmTest.new
      Langchain::LLM::OpenAI.stubs(:new).returns(@openai_mock)
      @llm = RedmineAiHelper::Llm.new(@params)
      @conversation = AiHelperConversation.new(title: "test task")
      message = AiHelperMessage.new(content: "test task", role: "user")
      @conversation.messages << message
    end

    should "respond with assistant role on chat success" do
      message = AiHelperMessage.new(content: "hello", role: "user")
      @conversation.messages << message
      response = @llm.chat(@conversation, nil, { controller_name: "issues", action_name: "show", content_id: 1 })
      assert_equal "assistant", response.role
    end

    context "issue summary" do
      setup do
        @issue = Issue.find(1)
        @llm = RedmineAiHelper::Llm.new(@params)
      end

      should "deny access for non-visible issue" do
        @issue.stubs(:visible?).returns(false)
        summary = @llm.issue_summary(issue: @issue)
        assert_equal "Permission denied", summary
      end
    end

    context "generate_issue_reply" do
      setup do
        @issue = Issue.find(1)
        @llm = RedmineAiHelper::Llm.new(@params)
      end

      should "deny access for non-visible issue" do
        @issue.stubs(:visible?).returns(false)
        reply = @llm.generate_issue_reply(issue: @issue, instructions: "test instructions")
        assert_equal "Permission denied", reply
      end

      should "generate reply for visible issue" do
        @issue.stubs(:visible?).returns(true)
        RedmineAiHelper::Agents::IssueAgent.any_instance.stubs(:generate_issue_reply).returns("Generated reply")
        reply = @llm.generate_issue_reply(issue: @issue, instructions: "test instructions")
        assert_equal "Generated reply", reply
      end
    end

    context "generate_sub_issues" do
      setup do
        @issue = Issue.find(1)
        @llm = RedmineAiHelper::Llm.new(@params)
        RedmineAiHelper::Agents::IssueAgent.stubs(:new).returns(DummyIssueAgent.new)
      end

      should "deny access for non-visible issue" do
        @issue.stubs(:visible?).returns(false)
        sub_issues = @llm.generate_sub_issues(issue: @issue, instructions: "test instructions")
        assert_equal "Permission denied", sub_issues
      end

      should "generate sub issues for visible issue" do
        @issue.stubs(:visible?).returns(true)
        RedmineAiHelper::Agents::IssueAgent.any_instance.stubs(:generate_sub_issues).returns([Issue.new(subject: "Sub issue 1"), Issue.new(subject: "Sub issue 2")])
        sub_issues = @llm.generate_sub_issues(issue: @issue, instructions: "test instructions")
        assert_equal 2, sub_issues.length
        assert_equal "Sub issue 1", sub_issues[0].subject
      end
    end

    context "wiki_summary" do
      setup do
        @wiki = Wiki.find(1)
        @wiki_page = @wiki.pages.first
        @llm = RedmineAiHelper::Llm.new(@params)
      end

      should "generate summary for wiki page" do
        summary = @llm.wiki_summary(wiki_page: @wiki_page)
        assert_equal "test answer", summary
      end

      should "generate summary for visible wiki page" do
        @wiki_page.stubs(:visible?).returns(true)
        summary = @llm.wiki_summary(wiki_page: @wiki_page)
        assert_equal "test answer", summary
      end
    end

    context "find_similar_issues" do
      setup do
        @issue = Issue.find(1)
        @llm = RedmineAiHelper::Llm.new(@params)
      end

      should "deny access for non-visible issue" do
        @issue.stubs(:visible?).returns(false)
        result = @llm.find_similar_issues(issue: @issue)
        assert_equal [], result
      end

      should "return empty array when no similar issues found" do
        @issue.stubs(:visible?).returns(true)
        result = @llm.find_similar_issues(issue: @issue)
        assert_equal [], result
      end
    end

    context "error handling" do
      should "handle basic chat functionality" do
        message = AiHelperMessage.new(content: "test", role: "user")
        @conversation.messages << message
        
        result = @llm.chat(@conversation, nil, { controller_name: "issues", action_name: "show", content_id: 1 })
        assert_equal "assistant", result.role
        assert_not_nil result.content
      end
    end

    context "permission checks" do
      setup do
        @issue = Issue.find(1)
        @wiki_page = WikiPage.first
        @llm = RedmineAiHelper::Llm.new(@params)
      end

      should "check issue visibility for issue_summary" do
        @issue.expects(:visible?).returns(false)
        
        result = @llm.issue_summary(issue: @issue)
        assert_equal "Permission denied", result
      end

      should "check issue visibility for generate_issue_reply" do
        @issue.expects(:visible?).returns(false)
        
        result = @llm.generate_issue_reply(issue: @issue, instructions: "test")
        assert_equal "Permission denied", result
      end

      should "check issue visibility for generate_sub_issues" do
        @issue.expects(:visible?).returns(false)
        
        result = @llm.generate_sub_issues(issue: @issue, instructions: "test")
        assert_equal "Permission denied", result
      end

      should "generate wiki summary successfully" do
        result = @llm.wiki_summary(wiki_page: @wiki_page)
        assert_equal "test answer", result
      end
    end
  end

  private

  def chat_answer_generator(message)
    { "choices": [{ "message": { "content": message } }] }
  end

  class DummyOpenAIClientForLlmTest < Langchain::LLM::OpenAI
    attr_accessor :langfuse

    def initialize(params = {})
      super(api_key: "aaaa")
    end

    def chat_answer(message)
      { "choices": [{ "message": { "content": message } }] }
    end

    def chat(params = {})
      messages = params[:messages]
      message = messages.last[:content]

      answer = "test answer"
      if message.include?("タスクに対する最終回答を作成してください")
        answer = "merged result"
        if message.include?("merge_results_test")
          answer = "merged result ok"
        end
      elsif message.include?("というタスクを解決するのに最適なツールを")
        answer = { "tool" => { "provider" => "project_tool_provider", "tool" => "read_project", "arguments" => { "id": ["1"] } } }.to_json
        if message.include?("dispatch_success_test")
          answer = { "tool" => { "provider" => "project_tool_provider", "tool" => "read_project", "arguments" => { "id": ["1"] } } }.to_json
        elsif message.include?("execute_task_error")
          answer = { "tool" => { "provider" => "project_tool_provider", "tool" => "read_project", "arguments" => { "id": ["999"] } } }.to_json
        elsif message.include?("dispatch_error")
          answer = { "tool" => { "provider" => "aaaa", "tool" => "read_project", "arguments" => { "id": ["999"] } } }.to_json
        end
      elsif message.include?("provide step-by-step instructions")
        answer = { "steps" => [{ "name" => "step1", "step" => "do something" }] }.to_json
      elsif message.include?("To achieve the goal of")
        answer = {
          "steps": [
            { "agent": "leader", "step": "my_projectという名前のプロジェクトのIDを教えてください" },
          ],
        }.to_json
      end

      if block_given?
        chunk = {
          "index": 0,
          "delta": { "content": answer },
          "finish_reason": nil,
        }.deep_stringify_keys
        yield(chunk)
      end

      response = { "choices": [{ "message": { "content": answer } }] }.deep_stringify_keys
      response
    end
  end

  context "wiki summary" do
    setup do
      @wiki = wikis(:wikis_001)
      @wiki_page = wiki_pages(:wiki_pages_001)
      @llm = RedmineAiHelper::Llm.new(@params)
      
      # Create a mock wiki content
      @wiki_content = WikiContent.new(
        page: @wiki_page,
        text: "This is test wiki content for summarization testing.",
        author: User.find(1),
        version: 1
      )
      @wiki_page.stubs(:content).returns(@wiki_content)
    end

    should "generate wiki summary successfully" do
      # Mock the WikiAgent and its wiki_summary method
      mock_agent = mock('wiki_agent')
      mock_agent.stubs(:wiki_summary).returns("Test wiki summary content")
      RedmineAiHelper::Agents::WikiAgent.stubs(:new).returns(mock_agent)
      
      summary = @llm.wiki_summary(wiki_page: @wiki_page)
      assert_not_nil summary
      assert_equal "Test wiki summary content", summary
    end

    should "handle errors during wiki summary generation" do
      # Mock WikiAgent to raise an error
      RedmineAiHelper::Agents::WikiAgent.stubs(:new).raises(StandardError.new("Test error"))
      
      summary = @llm.wiki_summary(wiki_page: @wiki_page)
      assert_equal "Test error", summary
    end

    should "create langfuse trace for wiki summary" do
      # Mock langfuse wrapper
      mock_langfuse = mock('langfuse_wrapper')
      mock_langfuse.stubs(:create_span)
      mock_langfuse.stubs(:finish_current_span)
      mock_langfuse.stubs(:flush)
      RedmineAiHelper::LangfuseUtil::LangfuseWrapper.stubs(:new).returns(mock_langfuse)
      
      # Mock WikiAgent
      mock_agent = mock('wiki_agent')
      mock_agent.stubs(:wiki_summary).returns("Summary with langfuse")
      RedmineAiHelper::Agents::WikiAgent.stubs(:new).returns(mock_agent)
      
      summary = @llm.wiki_summary(wiki_page: @wiki_page)
      assert_equal "Summary with langfuse", summary
    end

    should "pass correct parameters to WikiAgent" do
      # Verify WikiAgent is created with correct project
      RedmineAiHelper::Agents::WikiAgent.expects(:new).with(
        project: @wiki_page.wiki.project,
        langfuse: anything
      ).returns(mock('agent').tap do |agent|
        agent.stubs(:wiki_summary).with(wiki_page: @wiki_page, stream_proc: nil).returns("Summary")
      end)
      
      @llm.wiki_summary(wiki_page: @wiki_page)
    end

    should "log summary result" do
      mock_agent = mock('wiki_agent')
      mock_agent.stubs(:wiki_summary).returns("Logged summary")
      RedmineAiHelper::Agents::WikiAgent.stubs(:new).returns(mock_agent)
      
      # Expect logging
      @llm.expects(:ai_helper_logger).returns(mock('logger').tap do |logger|
        logger.expects(:info).with("answer: Logged summary")
      end)
      
      @llm.wiki_summary(wiki_page: @wiki_page)
    end
  end

  context "find_similar_issues" do
    setup do
      @issue = Issue.find(1)
      @llm = RedmineAiHelper::Llm.new(@params)
    end

    should "find similar issues successfully" do
      # Mock langfuse wrapper
      mock_langfuse = mock('langfuse_wrapper')
      mock_langfuse.stubs(:create_span)
      mock_langfuse.stubs(:finish_current_span)
      mock_langfuse.stubs(:flush)
      RedmineAiHelper::LangfuseUtil::LangfuseWrapper.stubs(:new).returns(mock_langfuse)
      
      # Mock IssueAgent
      similar_issues_data = [
        { id: 2, subject: "Similar issue", similarity_score: 85.0 }
      ]
      mock_agent = mock('issue_agent')
      mock_agent.stubs(:find_similar_issues).with(issue: @issue).returns(similar_issues_data)
      RedmineAiHelper::Agents::IssueAgent.stubs(:new).returns(mock_agent)
      
      result = @llm.find_similar_issues(issue: @issue)
      assert_equal similar_issues_data, result
    end

    should "handle errors during similar issues search" do
      # Mock IssueAgent to raise an error
      RedmineAiHelper::Agents::IssueAgent.stubs(:new).raises(StandardError.new("Vector search failed"))
      
      assert_raises(StandardError, "Vector search failed") do
        @llm.find_similar_issues(issue: @issue)
      end
    end

    should "create langfuse trace for similar issues search" do
      # Mock langfuse wrapper with expectations
      mock_langfuse = mock('langfuse_wrapper')
      mock_langfuse.expects(:create_span).with(name: "find_similar_issues", input: "issue_id: #{@issue.id}")
      mock_langfuse.expects(:finish_current_span).with(anything)
      mock_langfuse.expects(:flush)
      RedmineAiHelper::LangfuseUtil::LangfuseWrapper.stubs(:new).with(input: "find similar issues for #{@issue.id}").returns(mock_langfuse)
      
      # Mock IssueAgent
      similar_issues_data = []
      mock_agent = mock('issue_agent')
      mock_agent.stubs(:find_similar_issues).returns(similar_issues_data)
      RedmineAiHelper::Agents::IssueAgent.stubs(:new).returns(mock_agent)
      
      result = @llm.find_similar_issues(issue: @issue)
      assert_equal similar_issues_data, result
    end

    should "pass correct parameters to IssueAgent" do
      # Mock langfuse
      mock_langfuse = mock('langfuse_wrapper')
      mock_langfuse.stubs(:create_span)
      mock_langfuse.stubs(:finish_current_span)
      mock_langfuse.stubs(:flush)
      RedmineAiHelper::LangfuseUtil::LangfuseWrapper.stubs(:new).returns(mock_langfuse)
      
      # Verify IssueAgent is created with correct project and langfuse
      RedmineAiHelper::Agents::IssueAgent.expects(:new).with(
        project: @issue.project,
        langfuse: mock_langfuse
      ).returns(mock('agent').tap do |agent|
        agent.stubs(:find_similar_issues).with(issue: @issue).returns([])
      end)
      
      @llm.find_similar_issues(issue: @issue)
    end

    should "log errors and re-raise them" do
      # Mock langfuse
      mock_langfuse = mock('langfuse_wrapper')
      mock_langfuse.stubs(:create_span)
      mock_langfuse.stubs(:finish_current_span)
      mock_langfuse.stubs(:flush)
      RedmineAiHelper::LangfuseUtil::LangfuseWrapper.stubs(:new).returns(mock_langfuse)
      
      # Mock IssueAgent to raise an error
      mock_agent = mock('issue_agent')
      mock_agent.stubs(:find_similar_issues).raises(StandardError.new("Test error"))
      RedmineAiHelper::Agents::IssueAgent.stubs(:new).returns(mock_agent)
      
      # Expect error logging
      @llm.expects(:ai_helper_logger).returns(mock('logger').tap do |logger|
        logger.expects(:error).with(regexp_matches(/error:/))
      end)
      
      assert_raises(StandardError, "Test error") do
        @llm.find_similar_issues(issue: @issue)
      end
    end
  end

  class DummyIssueAgent
    def generate_sub_issues_draft(args = {})
      return "Permission denied" unless args[:issue].visible?
      [
        Issue.new(subject: "Sub issue 1", tracker_id: 1, project_id: 1),
        Issue.new(subject: "Sub issue 2", tracker_id: 1, project_id: 1),
      ]
    end
  end
end
