class JapaneseTextRefiner
  SYSTEM_PROMPT = <<~PROMPT.freeze
    あなたは日本語の校正者です。以下の制約でテキストを自然で読みやすく直してください。
    - 意味を変えない
    - 誤変換や不自然な助詞・語尾を適切に直す
    - 冗長なフィラー（えー、あのー等）や重複語を簡潔にする
    - 口語のニュアンスは保つ（ビジネス文脈で違和感がない範囲）
    - 文の区切りを適切にし、読点/句点を整える
    - 出力は校正後の本文のみ（説明や注釈は不要）
  PROMPT

  DEFAULT_MODEL = ENV.fetch('OPENAI_MODEL', 'gpt-4o-mini')

  def initialize(client: nil, model: DEFAULT_MODEL)
    @client = client || (OpenAI.configuration.access_token.present? ? OpenAI::Client.new : nil)
    @model = model
  end

  def refine_text(text)
    return heuristic_refine(text) if text.to_s.strip.empty?

    if @client.nil?
      return heuristic_refine(text)
    end

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
      return heuristic_refine(text) if content.blank?
      content
    rescue => e
      Rails.logger.warn("[JapaneseTextRefiner] fallback due to: #{e.class}: #{e.message}")
      heuristic_refine(text)
    end
  end

  private

  # 軽量なヒューリスティック校正（OpenAI未設定時のフォールバック）
  def heuristic_refine(text)
    t = text.to_s.dup
    t.gsub!(/[ \t\f\v]+/, ' ')
    t.gsub!(/[。]{2,}/, '。')
    t.gsub!(/[、]{2,}/, '、')
    t.gsub!(/(えー|あのー|そのー|えっと)[、。]?/,'')
    t.gsub!(/\s*([、。])\s*/, '\1')
    t.strip
  end
end
