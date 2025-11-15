module Chats
  class StreamingResponseService
    RESPONSES_PER_MESSAGE = 1
    DEFAULT_MODEL = "gpt-4o-mini".freeze

    def initialize(chat:)
      @chat = chat
    end

    def call
      return handle_missing_api_key unless api_key_configured?

      placeholders = []
      placeholders = build_placeholders
      # Generate prompt after inserting placeholders so UI immediately shows "回答を生成中"
      # prompt_messages = Message.for_openai(chat.messages)
      prompt_messages = ChatPromptBuilder.build(chat: chat)
      stream_response(prompt_messages, placeholders)
    rescue StandardError => e
      Rails.logger.error("[ChatStreaming] #{e.class}: #{e.message}")
      handle_stream_error(placeholders, e)
    end

    private

    attr_reader :chat

    def api_key_configured?
      OpenAI.configuration.access_token.present?
    end

    def handle_missing_api_key
      chat.messages.create!(
        role: :assistant,
        content: "OpenAI APIキーが設定されていないため、回答を生成できません。"
      )
    end

    def build_placeholders
      Array.new(RESPONSES_PER_MESSAGE) do |index|
        chat.messages.create!(role: :assistant, content: "", response_number: index)
      end
    end

    def stream_response(prompt_messages, placeholders)
      Rails.logger.info("[ChatStreaming] Calling OpenAI chat: chat_id=#{chat.id} model=#{DEFAULT_MODEL}")
      client.chat(
        parameters: {
          model: DEFAULT_MODEL,
          messages: prompt_messages,
          temperature: 0.7,
          stream: stream_proc(placeholders),
          n: RESPONSES_PER_MESSAGE
        }
      )
    end

    def client
      @client ||= OpenAI::Client.new
    end

    def stream_proc(placeholders)
      proc do |chunk, _bytesize|
        index = chunk.dig("choices", 0, "index")
        new_content = chunk.dig("choices", 0, "delta", "content")
        next if index.nil?

        message = placeholders.find { |placeholder| placeholder.response_number == index }
        next if message.nil? || new_content.blank?

        message.update(content: "#{message.content}#{new_content}")
      end
    end

    def handle_stream_error(placeholders, error)
      return if placeholders.blank?

      placeholders.each do |message|
        message.update(content: "回答の生成中にエラーが発生しました: #{error.message}")
      end
    end
  end
end
