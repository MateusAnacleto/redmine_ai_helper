require File.expand_path("../../../test_helper", __FILE__)

class RedmineAiHelper::Tools::VectorToolsTest < ActiveSupport::TestCase
  fixtures :projects, :issues, :issue_statuses, :trackers, :enumerations, :users, :issue_categories, :versions, :custom_fields, :wikis, :wiki_pages

  context "VectorTools" do
    setup do
      @vector_tools = RedmineAiHelper::Tools::VectorTools.new
      @mock_db = mock("vector_db")
      @mock_logger = mock("logger")
      @setting = mock("AiHelperSetting")
      @setting.stubs(:vector_search_enabled).returns(true)
      AiHelperSetting.stubs(:find_or_create).returns(@setting)
      @vector_tools.stubs(:ai_helper_logger).returns(@mock_logger)
      @mock_logger.stubs(:debug)
      @mock_logger.stubs(:error)
    end

    should "raise error if vector search is not enabled" do
      @setting.stubs(:vector_search_enabled).returns(false)
      assert_raises(RuntimeError, "The vector search functionality is not enabled.") do
        @vector_tools.ask_with_filter(query: "foo", k: 10, filter: {}, target: "issue")
      end
    end

    should "raise error if k is out of range" do
      assert_raises(RuntimeError, "limit must be between 1 and 50.") do
        @vector_tools.ask_with_filter(query: "foo", k: 0, filter: {}, target: "issue")
      end
      assert_raises(RuntimeError, "limit must be between 1 and 50.") do
        @vector_tools.ask_with_filter(query: "foo", k: 51, filter: {}, target: "issue")
      end
    end

    should "call vector_db and return response when target is issue" do
      @vector_tools.stubs(:vector_db).with(target: "issue").returns(@mock_db)
      @mock_db.expects(:ask_with_filter).with(query: "foo bar", k: 10, filter: {}).returns([{ "issue_id" => 1 }])
      result = @vector_tools.ask_with_filter(query: "foo bar", k: 10, filter: {}, target: "issue")
      assert_equal 1, result.first[:id]
    end

    should "call vector_db and return response when target is wiki" do
      @vector_tools.stubs(:vector_db).with(target: "wiki").returns(@mock_db)
      @mock_db.expects(:ask_with_filter).with(query: "foo bar", k: 10, filter: {}).returns([{ "wiki_id" => 1 }])
      result = @vector_tools.ask_with_filter(query: "foo bar", k: 10, filter: {}, target: "wiki")
      wiki = WikiPage.find_by(id: 1)
      assert_equal wiki.title, result.first[:title]
    end

    should "log and raise error if exception occurs" do
      @vector_tools.stubs(:vector_db).with(target: "issue").raises(StandardError.new("db error"))
      @mock_logger.expects(:error).at_least_once
      assert_raises(RuntimeError, "Error: db error") do
        @vector_tools.ask_with_filter(query: "foo", k: 10, filter: {}, target: "issue")
      end
    end

    context "#create_filter" do
      should "convert filter items with _id to integer" do
        filter = [
          { key: "project_id", condition: "match", value: "123" },
        ]
        result = @vector_tools.send(:create_filter, filter)
        assert_equal [{ key: "project_id", match: { value: 123 } }], result
      end

      should "convert filter items with other keys to string" do
        filter = [
          { key: "created_on", condition: "match", value: "2024-01-01" },
        ]
        result = @vector_tools.send(:create_filter, filter)
        assert_equal [{ key: "created_on", match: { value: "2024-01-01" } }], result
      end

      should "handle lt/lte/gt/gte conditions" do
        filter = [
          { key: "priority_id", condition: "lt", value: "5" },
        ]
        result = @vector_tools.send(:create_filter, filter)
        assert_equal [{ key: "priority_id", rante: { "lt" => 5 } }], result
      end
    end

    context "#vector_db" do
      should "return IssueVectorDb for target issue" do
        RedmineAiHelper::Vector::IssueVectorDb.expects(:new).returns(:issue_db)
        @vector_tools.instance_variable_set(:@vector_db, nil)
        assert_equal :issue_db, @vector_tools.send(:vector_db, target: "issue")
      end

      should "return WikiVectorDb for target wiki" do
        RedmineAiHelper::Vector::WikiVectorDb.expects(:new).returns(:wiki_db)
        @vector_tools.instance_variable_set(:@vector_db, nil)
        assert_equal :wiki_db, @vector_tools.send(:vector_db, target: "wiki")
      end

      should "raise error for invalid target" do
        assert_raises(RuntimeError, "Invalid target: foo. Must be 'issue' or 'wiki'.") do
          @vector_tools.send(:vector_db, target: "foo")
        end
      end
    end

    should "vector_db_enabled? returns true if setting is enabled" do
      @setting.stubs(:vector_search_enabled).returns(true)
      assert_equal true, @vector_tools.send(:vector_db_enabled?)
    end

    should "vector_db_enabled? returns false if setting is disabled" do
      @setting.stubs(:vector_search_enabled).returns(false)
      assert_equal false, @vector_tools.send(:vector_db_enabled?)
    end

    context "#find_similar_issues" do
      setup do
        @issue = Issue.find(1)
        @issue.project.enable_module!(:ai_helper)
        User.current = User.find(1)
        @mock_db = mock("vector_db")
        @vector_tools.stubs(:vector_db).with(target: "issue").returns(@mock_db)
        @mock_db.stubs(:client).returns(true)
        @mock_logger.stubs(:warn)
      end

      should "raise error if vector search is not enabled" do
        @setting.stubs(:vector_search_enabled).returns(false)
        assert_raises(RuntimeError, "The vector search functionality is not enabled.") do
          @vector_tools.find_similar_issues(issue_id: @issue.id, k: 10)
        end
      end

      should "raise error if k is out of range" do
        assert_raises(RuntimeError, "limit must be between 1 and 50.") do
          @vector_tools.find_similar_issues(issue_id: @issue.id, k: 0)
        end
        assert_raises(RuntimeError, "limit must be between 1 and 50.") do
          @vector_tools.find_similar_issues(issue_id: @issue.id, k: 51)
        end
      end

      should "raise error if issue not found" do
        assert_raises(RuntimeError, "Issue not found with ID: 99999") do
          @vector_tools.find_similar_issues(issue_id: 99999, k: 10)
        end
      end

      should "raise error if issue not visible" do
        # Issue.find_by should return the issue, then visible? should return false
        Issue.stubs(:find_by).with(id: @issue.id).returns(@issue)
        @issue.stubs(:visible?).returns(false)
        assert_raises(RuntimeError, "Permission denied") do
          @vector_tools.find_similar_issues(issue_id: @issue.id, k: 10)
        end
      end

      should "raise error if vector search client not available" do
        @mock_db.stubs(:client).returns(false)
        assert_raises(RuntimeError, "Vector search is not enabled or configured") do
          @vector_tools.find_similar_issues(issue_id: @issue.id, k: 10)
        end
      end

      should "return similar issues successfully" do
        # Create another issue for similar results
        other_issue = Issue.find(2)
        other_issue.project.enable_module!(:ai_helper)
        
        # Mock vector search results
        mock_results = [
          {
            "payload" => {
              "issue_id" => @issue.id  # Current issue - should be filtered out
            },
            "score" => 1.0
          },
          {
            "payload" => {
              "issue_id" => other_issue.id
            },
            "score" => 0.85
          }
        ]
        
        @mock_db.expects(:similarity_search).returns(mock_results)
        
        result = @vector_tools.find_similar_issues(issue_id: @issue.id, k: 10)
        
        assert_equal 1, result.length
        assert_equal other_issue.id, result.first[:id]
        assert_equal 85.0, result.first[:similarity_score]
      end

      should "filter out issues from projects without ai_helper module" do
        # Create issue in project without ai_helper module
        other_issue = Issue.find(2)
        other_issue.project.disable_module!(:ai_helper)
        
        mock_results = [
          {
            "payload" => {
              "issue_id" => other_issue.id
            },
            "score" => 0.85
          }
        ]
        
        @mock_db.expects(:similarity_search).returns(mock_results)
        
        result = @vector_tools.find_similar_issues(issue_id: @issue.id, k: 10)
        
        assert_equal 0, result.length
      end

      should "handle issues that cause generate_issue_data to fail" do
        other_issue = Issue.find(2)
        other_issue.project.enable_module!(:ai_helper)
        
        mock_results = [
          {
            "payload" => {
              "issue_id" => other_issue.id
            },
            "score" => 0.85
          }
        ]
        
        @mock_db.expects(:similarity_search).returns(mock_results)
        
        # Mock generate_issue_data to raise an error
        @vector_tools.stubs(:generate_issue_data).raises(NoMethodError.new("undefined method `id' for nil:NilClass"))
        
        result = @vector_tools.find_similar_issues(issue_id: @issue.id, k: 10)
        
        # Should return empty array when generate_issue_data fails
        assert_equal 0, result.length
      end

      should "return empty array when no results from vector search" do
        @mock_db.expects(:similarity_search).returns([])
        
        result = @vector_tools.find_similar_issues(issue_id: @issue.id, k: 10)
        
        assert_equal 0, result.length
      end

      should "handle nil results from vector search" do
        @mock_db.expects(:similarity_search).returns(nil)
        
        result = @vector_tools.find_similar_issues(issue_id: @issue.id, k: 10)
        
        assert_equal 0, result.length
      end
    end
  end
end
