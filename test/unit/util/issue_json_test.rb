require File.expand_path("../../../test_helper", __FILE__)
require "redmine_ai_helper/util/issue_json"

class RedmineAiHelper::Util::IssueJsonTest < ActiveSupport::TestCase
  fixtures :projects, :issues, :issue_statuses, :trackers, :enumerations, :users, :issue_categories, :versions, :custom_fields, :attachments, :changesets, :journals, :journal_details, :changes

  context "generate_issue_data" do
    setup do
      @issue = Issue.first
      @issue.assigned_to = User.find(2)

      @issue.status = IssueStatus.find(2)
      @issue.save!
      issue2 = Issue.find(2)
      issue2.parent = @issue
      issue2.save!
      @issue.reload
      changeset = Changeset.first
      changeset.issues << @issue
      changeset.save!
      attachment = Attachment.find(1)
      attachment.container = @issue
      attachment.save!
      @issue.reload
      @test_class = TestClass.new
      @issue.due_date = Date.today + 7
    end

    should "generate correct issue data" do
      issue_data = @test_class.generate_issue_data(@issue)
      # puts JSON.pretty_generate(issue_data)

      assert_equal @issue.id, issue_data[:id]
      assert_equal @issue.subject, issue_data[:subject]
      assert_equal @issue.project.id, issue_data[:project][:id]
      assert_equal @issue.project.name, issue_data[:project][:name]
      assert_equal @issue.tracker.id, issue_data[:tracker][:id]
      assert_equal @issue.tracker.name, issue_data[:tracker][:name]
      assert_equal @issue.status.id, issue_data[:status][:id]
      assert_equal @issue.status.name, issue_data[:status][:name]
      assert_equal @issue.priority.id, issue_data[:priority][:id]
      assert_equal @issue.priority.name, issue_data[:priority][:name]
      assert_equal @issue.author.id, issue_data[:author][:id]
      assert_equal @issue.assigned_to.id, issue_data[:assigned_to][:id]
      assert_equal @issue.description, issue_data[:description]
      assert_equal @issue.start_date, issue_data[:start_date]
      assert_equal @issue.due_date, issue_data[:due_date]
      assert_equal @issue.done_ratio, issue_data[:done_ratio]
      assert_equal @issue.is_private, issue_data[:is_private]
      assert_equal @issue.estimated_hours, issue_data[:estimated_hours]
      assert_equal @issue.created_on.to_s, issue_data[:created_on].to_s
      assert_equal @issue.updated_on.to_s, issue_data[:updated_on].to_s
    end
  end

  class TestClass < RedmineAiHelper::BaseTools
    # This class is used to test the IssueJson module
    # It includes the IssueJson module to access its methods
    include RedmineAiHelper::Util::IssueJson
  end
end
