module Chats
  class AiResponseJob < ApplicationJob
    queue_as :default

    def perform(chat_id)
      chat = Chat.includes(:messages, :workspace, :product, :sales_expert).find_by(id: chat_id)
      return if chat.nil?

      Chats::StreamingResponseService.new(chat: chat).call
    end
  end
end
