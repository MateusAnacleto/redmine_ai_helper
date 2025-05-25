# frozen_string_literal: true
require "json"

module RedmineAiHelper
  module Vector
    # This class is responsible for managing the vector database for issues in Redmine.
    class WikiVectorDb < VectorDb
      def index_name
        "RedmineWiki"
      end

      # Checks whether an Issue with the specified ID exists.
      # @param object_id [Integer] The ID of the issue to check.
      def data_exists?(object_id)
        WikiPage.exists?(id: object_id)
      end

      # A method to generate content and payload for registering an issue into the vector database
      # @param issue [Issue] The issue to be registered.
      # @return [Hash] A hash containing the content and payload for the issue.
      # @note This method is used to prepare the data for vector database registration.
      def data_to_json(wiki)
        payload = {
          wiki_id: wiki.id,
          project_id: wiki.project&.id,
          project_name: wiki.project&.name,
          created_on: wiki.created_on,
          updated_on: wiki.updated_on,
          parent_id: wiki.parent_id,
          parent_title: wiki.parent_title,
        }
        content = "#{wiki.title} #{wiki.content.text}"

        return { content: content, payload: payload }
      end
    end
  end
end
