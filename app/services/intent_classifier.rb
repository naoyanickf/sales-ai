class IntentClassifier
  MODEL = "gpt-4o-mini".freeze
  TEMPERATURE = 0.0
  MAX_TOKENS = 32
  HISTORY_CHAR_LIMIT = 800
  LABEL_GENERAL = "GENERAL".freeze
  LABEL_PRODUCT = "PRODUCT".freeze
  LABELS = [LABEL_GENERAL, LABEL_PRODUCT].freeze

  def self.call(query:, history: nil, logger: Rails.logger)
    new(query: query, history: history, logger: logger).call
  end

  def initialize(query:, history:, logger: Rails.logger)
    @query = query.to_s.strip
    @history = history.to_s.strip
    @logger = logger
  end

  def call
    return nil if query.blank?
    return nil unless api_key_configured?

    label = classify_with_openai
    to_intent(label)
  rescue StandardError => e
    logger.warn("[IntentClassifier] #{e.class}: #{e.message}")
    nil
  end

  private

  attr_reader :query, :history, :logger

  def api_key_configured?
    OpenAI.configuration.access_token.present?
  end

  def client
    @client ||= OpenAI::Client.new
  end

  def classify_with_openai
    response = client.chat(
      parameters: {
        model: MODEL,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: TEMPERATURE,
        max_tokens: MAX_TOKENS
      }
    )
    response.dig("choices", 0, "message", "content")
  end

  def system_prompt
    <<~PROMPT.squish
      あなたは営業相談の種類を分類するアシスタントです。
      出力は GENERAL または PRODUCT のどちらか1語のみで返してください。
      製品情報や価格・機能といった具体的な説明を求めている場合は PRODUCT、それ以外の雑談や一般的な相談であれば GENERAL を選択します。
    PROMPT
  end

  def user_prompt
    <<~PROMPT
      最新の相談内容と直近の会話を示します。GENERAL または PRODUCT のいずれかを出力してください。

      最新相談:
      #{query}

      直近会話:
      #{trimmed_history.presence || "（履歴なし）"}
    PROMPT
  end

  def trimmed_history
    history.length > HISTORY_CHAR_LIMIT ? "#{history[0...HISTORY_CHAR_LIMIT]}…" : history
  end

  def to_intent(label)
    normalized = label.to_s.upcase.strip
    case normalized
    when LABEL_PRODUCT
      :product
    when LABEL_GENERAL
      :general
    else
      nil
    end
  end
end
