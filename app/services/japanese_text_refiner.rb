class JapaneseTextRefiner
  SYSTEM_PROMPT = <<~PROMPT.freeze
    あなたは日本語の校正者です。以下の制約でテキストを自然で読みやすく直してください。
    - 意味を変えない
    - 誤変換や不自然な助詞・語尾を適切に直す
    - 口語のニュアンスは保つ（ビジネス文脈で違和感がない範囲）
    - 敬体/常体は元の文に合わせる
    - 出力は校正後の本文のみ（説明や注釈は不要）
  PROMPT

  DEFAULT_MODEL = ENV.fetch('OPENAI_MODEL', 'gpt-4o-mini')

  def initialize(client: defined?(OPENAI_CLIENT) ? OPENAI_CLIENT : nil, model: DEFAULT_MODEL)
    @client = client
    @model = model
  end

  def refine_text(text)
    return text if text.blank? || @client.nil?

    begin
      response = @client.chat(
        parameters: {
          model: @model,
          messages: [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: text.to_s }
          ],
          temperature: 0.2
        }
      )

      content = response.dig('choices', 0, 'message', 'content')
      content.present? ? content : text
    rescue => e
      Rails.logger.warn("[JapaneseTextRefiner] fallback due to: #{e.class}: #{e.message}")
      text
    end
  end
end

