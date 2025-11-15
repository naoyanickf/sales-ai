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
      append_expert_sources_footer
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

    def append_expert_sources_footer
      return unless chat.sales_expert.present?
      latest_user = chat.messages
        .where(role: Message.roles[:user])
        .order(created_at: :desc, id: :desc)
        .limit(1)
        .first
      query = latest_user&.content.to_s
      return if query.blank?

      hits = ExpertRag.fetch(sales_expert: chat.sales_expert, query: query, limit: 3)
      return if hits.blank?

      lines = hits.map do |h|
        chunk = KnowledgeChunk.find_by(id: h[:id])
        next unless chunk
        t = chunk.expert_knowledge&.transcription
        next unless t
        seg_id = Array(chunk.transcription_segment_ids).first
        anchor = seg_id ? "#seg-#{seg_id}" : nil
        path = Rails.application.routes.url_helpers.transcription_path(t)
        link = [path, anchor].compact.join
        "- 出典##{chunk.id}: #{link}"
      end.compact

      return if lines.blank?

      content = "参考: 先輩RAG出典\n" + lines.join("\n")
      chat.messages.create!(role: :assistant, content: content)
    rescue => e
      Rails.logger.warn("[ChatStreaming] append_expert_sources_footer failed: #{e.class} #{e.message}")
    end
  end
end
