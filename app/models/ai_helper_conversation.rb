# frozen_string_literal: true
# AiHelperConversation model for managing AI Helper conversations
class AiHelperConversation < ApplicationRecord
  has_many :messages, class_name: "AiHelperMessage", foreign_key: "conversation_id", dependent: :destroy
  belongs_to :user
  validates :title, presence: true
  validates :user_id, presence: true

  # Returns the last message in the conversation
  def messages_for_openai
    messages.map do |message|
      {
        role: message.role,
        content: message.content,
      }
    end
  end
end
