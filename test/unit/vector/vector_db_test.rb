require File.expand_path("../../../test_helper", __FILE__)
require "redmine_ai_helper/vector/vector_db"

class RedmineAiHelper::Vector::VectorDbTest < ActiveSupport::TestCase
  fixtures :projects, :issues, :issue_statuses, :trackers, :enumerations, :users, :issue_categories, :versions, :custom_fields
  context "VectorDb" do
    setup do
      @qdrant_stub = QdrantStub.new
      RedmineAiHelper::Vector::Qdrant.stubs(:new).returns(@qdrant_stub)
      @vector_db = RedmineAiHelper::Vector::VectorDb.new
      @issue_vector_db = RedmineAiHelper::Vector::IssueVectorDb.new
      @setting = AiHelperSetting.find_or_create
      @setting.vector_search_enabled = true
      @setting.vector_search_uri = "http://example.com"
      @setting.save!
      AiHelperVectorData.destroy_all
    end

    teardown do
      @setting.vector_search_enabled = false
      @setting.save!
    end

    should "return client" do
      client = @issue_vector_db.client
      assert client
    end

    should "raise error with index_name" do
      assert_raises NotImplementedError do
        @vector_db.index_name
      end
    end

    should "raise error with data_exists?" do
      assert_raises NotImplementedError do
        @vector_db.data_exists?(1)
      end
    end

    should "not error with generate_schema" do
      assert @issue_vector_db.generate_schema
    end

    should "not error with destory_schema" do
      assert @issue_vector_db.destroy_schema
    end

    context "add_datas" do
      setup do
      end

      should "add vector data" do
        issue = Issue.first
        issue.description = "#{"a" * 2000}"
        issue.save!
        issues = Issue.all
        @issue_vector_db.add_datas(datas: issues)
        assert issues.length, AiHelperVectorData.all.length
        issue.subject = "aaaa"
        issue.save!
        issues = Issue.all
        @issue_vector_db.add_datas(datas: issues)
        assert issues.length, AiHelperVectorData.all.length
      end

      should "clean_vector_data deletes data" do
        issues = Issue.all
        @issue_vector_db.add_datas(datas: issues)
        issues.first.destroy!
        issues = Issue.all
        @issue_vector_db.clean_vector_data
        assert issues.length, AiHelperVectorData.all.length
      end
    end
  end

  class QdrantStub
    def create_default_schema
      return ""
    end

    def destroy_default_schema
      true
    end

    def add_texts(texts:, ids:, payload:)
      if (texts[0].length > 1500)
        raise "Error"
      end
    end

    def remove_texts(ids:)
      true
    end
  end
end
