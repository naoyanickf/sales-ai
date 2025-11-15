module Chats
  class TitleGenerator
    FAST_MODEL = "gpt-4o-mini".freeze
    MAX_LENGTH = 30
    DEFAULT_TITLE = "新しい相談".freeze

    def initialize(content:)
      @content = content.to_s.strip
    end

    def call
      return fallback_title if content.blank?
      return fallback_title unless api_key_configured?

      title = generate_title_from_openai
      sanitize_title(title).presence || fallback_title
    rescue StandardError => e
      Rails.logger.warn("[ChatTitle] #{e.class}: #{e.message}")
      fallback_title
    end

    private

    attr_reader :content

    def api_key_configured?
      OpenAI.configuration.access_token.present?
    end

    def client
      @client ||= OpenAI::Client.new
    end

    def generate_title_from_openai
      response = client.chat(
        parameters: {
          model: FAST_MODEL,
          messages: [
            {
              role: "system",
              content: "あなたは営業相談の内容を短い件名にまとめるアシスタントです。"
            },
            {
              role: "user",
              content: title_prompt
            }
          ],
          temperature: 0.2,
          max_tokens: 50
        }
      )
      response.dig("choices", 0, "message", "content")
    end

    def title_prompt
      <<~PROMPT
        以下の相談内容を#{MAX_LENGTH}文字以内で簡潔な件名にしてください。
        ・句読点や記号を乱用せず自然な日本語にする
        ・引用符や記号で囲まない
        ・相談内容の核心が伝わるようにする

        相談内容:
        #{content}
      PROMPT
    end

    def sanitize_title(title)
      normalized = title.to_s.strip.gsub(/\s+/, " ")
      truncated(normalized)
    end

    def fallback_title
      truncated(content.presence || DEFAULT_TITLE)
    end

    def truncated(text)
      cleaned = text.to_s.strip
      return DEFAULT_TITLE if cleaned.blank?
      return cleaned if cleaned.length <= MAX_LENGTH

      "#{cleaned[0...MAX_LENGTH]}…"
    end
  end
end
