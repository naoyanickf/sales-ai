class ChatPromptBuilder
  INTENT_GENERAL = :general
  INTENT_PRODUCT = :product
  PRODUCT_KEYWORDS = %w[価格 料金 金額 見積 プラン 契約 導入 比較 連携 費用 機能 制約 製品].freeze
  HISTORY_LIMIT = 10
  PRODUCT_TEXT_LIMIT = 3_000
  PRODUCT_BULLET_LIMIT = 5
  PRODUCT_BULLET_TRUNCATE = 280
  EXPERT_TEXT_LIMIT = 2_000
  EXPERT_BULLET_LIMIT = 5
  EXPERT_BULLET_TRUNCATE = 240
  HISTORY_PLACEHOLDER = "（まだ会話履歴はありません）".freeze
  PRODUCT_PLACEHOLDER = "製品RAGからの情報はありません。".freeze
  EXPERT_PLACEHOLDER = "参照可能な先輩営業のトークデータがありません。".freeze

  def self.build(chat:, messages: nil, query: nil, logger: Rails.logger)
    new(chat: chat, messages: messages, query: query, logger: logger).build
  end

  def initialize(chat:, messages:, query:, logger: Rails.logger)
    @chat = chat
    @messages = Array(messages || chat&.messages || [])
    @logger = logger
    @query = (query.presence || detect_latest_user_query)
  end

  def build
    return fallback_payload if chat.nil? || messages.empty? || query.blank?

    intent = classify_intent
    product_context = needs_product_context?(intent) ? fetch_product_context : { text: nil, sources: [] }
    expert_context = needs_expert_context?(intent) ? fetch_expert_context : { text: nil, sources: [], name: sales_expert_name }

    log_prompt_metrics(intent: intent, product_context: product_context, expert_context: expert_context)

    [
      { role: "system", content: base_system_prompt },
      { role: "system", content: context_message(product_context[:text], expert_context: expert_context) },
      { role: "user", content: query }
    ]
  rescue StandardError => e
    logger.error("[ChatPromptBuilder] Failed to build prompt for Chat##{chat&.id}: #{e.class} #{e.message}")
    fallback_payload
  end

  private

  attr_reader :chat, :messages, :query, :logger

  def classify_intent
    intent = rule_based_intent
    return intent if intent.present?

    llm_intent = llm_classify_intent
    return llm_intent if llm_intent.present?

    INTENT_GENERAL
  end

  def llm_classify_intent
    IntentClassifier.call(
      query: query,
      history: intent_history_text,
      logger: logger
    )
  rescue StandardError => e
    logger.warn("[ChatPromptBuilder] Intent classification failed: #{e.class} #{e.message}")
    nil
  end

  def rule_based_intent
    return INTENT_PRODUCT if product_phrase?(query)

    recent_history = history_messages.last(5).map { |message| message.content.to_s }
    return INTENT_PRODUCT if recent_history.any? { |text| product_phrase?(text) }

    nil
  end

  def product_phrase?(text)
    normalized = text.to_s
    PRODUCT_KEYWORDS.any? { |keyword| normalized.include?(keyword) }
  end

  def needs_product_context?(intent)
    intent == INTENT_PRODUCT && chat&.product.present?
  end

  def needs_expert_context?(_intent)
    chat&.sales_expert.present?
  end

  def fetch_product_context
    ProductContextFetcher.new(chat.product, logger: logger).fetch(query)
  end

  def fetch_expert_context
    ExpertContextFetcher.new(chat.sales_expert, logger: logger).fetch(query)
  end

  def detect_latest_user_query
    latest_user_message&.content&.to_s&.strip
  end

  def latest_user_message
    @latest_user_message ||= messages.reverse.find(&:user?)
  end

  def history_messages
    @history_messages ||= begin
      latest = latest_user_message
      if latest.nil?
        messages
      else
        duped = messages.dup
        index = duped.rindex(latest)
        duped.delete_at(index) if index
        duped
      end
    end
  end

  def formatted_history
    relevant = history_messages.last(HISTORY_LIMIT)
    return HISTORY_PLACEHOLDER if relevant.empty?

    relevant.map do |message|
      label = history_label_for(message)
      content = sanitize_text(message.content)
      "#{label}: #{content}"
    end.join("\n")
  end

  def history_label_for(message)
    case message.role.to_s
    when "user" then "User"
    when "assistant" then "Sales AI"
    else "System"
    end
  end

  def intent_history_text
    history_messages
      .last(5)
      .map { |message| "#{message.role}: #{sanitize_text(message.content)}" }
      .join("\n")
  end

  def sanitize_text(text)
    text.to_s.squish.truncate(500)
  end

  def base_system_prompt
    <<~PROMPT.squish
      あなたは礼儀正しく信頼できるB2B営業アシスタントです。事実ベースで回答し、
      - 推測は避け、根拠のない数値は出さない
      - 不明点は率直に伝える
      - 依頼がなければ個別製品の価格・契約条件は disclose しない
      - 同僚や顧客を尊重した敬語で回答する
    PROMPT
  end

  def context_message(product_text, expert_context: {})
    product_section = product_text.presence || PRODUCT_PLACEHOLDER
    expert_name = expert_context[:name].presence || "先輩営業未指定"
    expert_section = expert_context[:text].presence || EXPERT_PLACEHOLDER
    <<~CONTEXT.strip
      ## Product Knowledge
      #{product_section}

      ## Expert Advice (#{expert_name})
      #{expert_section}

      ## 会話履歴
      #{formatted_history}

      ユーザーからの最新相談:
      #{query}

      回答指針:
      1. 相談の意図を要約してから助言する
      2. 製品情報を参照した箇所は簡潔に根拠を示す
      3. 次のアクション案を1～2個提示する
    CONTEXT
  end

  def sales_expert_name
    chat&.sales_expert&.name.to_s
  end

  def log_prompt_metrics(intent:, product_context:, expert_context:)
    metrics = {
      intent: intent,
      needs_product: needs_product_context?(intent),
      needs_expert: needs_expert_context?(intent),
      rag_sources: Array(product_context[:sources]).presence || [],
      expert_sources: Array(expert_context[:sources]).presence || [],
      prompt_has_product_context: product_context[:text].present?,
      prompt_has_expert_context: expert_context[:text].present?
    }
    logger.info("[ChatPromptBuilder] #{metrics.to_json}")
  rescue StandardError => e
    logger.debug("[ChatPromptBuilder] Failed to log metrics: #{e.class} #{e.message}")
  end

  def fallback_payload
    Message.for_openai(messages)
  end

  class ProductContextFetcher
    def initialize(product, logger:)
      @product = product
      @logger = logger
    end

    def fetch(query)
      return { text: nil, sources: [] } if product.blank? || query.blank?

      response = product.query_gemini_rag(query)
      text = summarize(response)
      {
        text: text,
        sources: extract_sources(response)
      }
    rescue StandardError => e
      logger.warn("[ChatPromptBuilder] Product RAG fetch failed for Product##{product&.id}: #{e.class} #{e.message}")
      { text: nil, sources: [] }
    end

    private

    attr_reader :product, :logger

    def summarize(response)
      raw = extract_text(response)
      compressed = compress_text(raw)
      return if compressed.blank?

      compressed
    end

    def extract_text(response)
      candidates = Array(response["candidates"])
      parts = candidates.flat_map { |candidate| Array(candidate.dig("content", "parts")) }
      texts = parts.map { |part| part["text"].to_s }.reject(&:blank?)
      texts.join("\n\n")
    end

    def compress_text(text)
      normalized = text.to_s.strip
      return if normalized.blank?

      paragraphs = normalized.split(/\n{2,}/).map(&:squish).reject(&:blank?)
      bullets = paragraphs.first(PRODUCT_BULLET_LIMIT).map do |section|
        "- #{truncate(section, PRODUCT_BULLET_TRUNCATE)}"
      end
      bullets.join("\n")[0, PRODUCT_TEXT_LIMIT]
    end

    def truncate(text, limit)
      return text if text.length <= limit

      "#{text[0, limit]}…"
    end

    def extract_sources(response)
      Array(response["candidates"]).flat_map.with_index do |candidate, c_index|
        metadata = candidate["groundingMetadata"] || {}
        chunks = Array(metadata["groundingChunks"])
        chunks.map.with_index do |chunk, index|
          chunk["id"].presence ||
            chunk.dig("retrievedContext", "title").presence ||
            chunk.dig("retrievedContext", "fileSearchStore").presence ||
            "candidate#{c_index}_chunk#{index}"
        end
      end.compact.uniq
    end
  end

  class ExpertContextFetcher
    def initialize(sales_expert, logger:)
      @sales_expert = sales_expert
      @logger = logger
    end

    def fetch(query)
      return { text: nil, sources: [], name: sales_expert_name } if sales_expert.blank? || query.to_s.strip.empty?

      hits = ExpertRag.fetch(sales_expert: sales_expert, query: query, limit: EXPERT_BULLET_LIMIT)
      return { text: nil, sources: [], name: sales_expert_name } if hits.empty?

      joined = hits.map { |h| h[:text].to_s.squish }.reject(&:blank?)
      text = compress_text(joined.join("\n\n"))
      sources = hits.map { |h| "chunk##{h[:id]}" }
      { text: text, sources: sources, name: sales_expert_name }
    rescue StandardError => e
      logger.warn("[ChatPromptBuilder] Expert context fetch failed for SalesExpert##{sales_expert&.id}: #{e.class} #{e.message}")
      { text: nil, sources: [], name: sales_expert_name }
    end

    private

    attr_reader :sales_expert, :logger

    def sales_expert_name
      sales_expert&.name.to_s
    end

    def compress_text(text)
      normalized = text.to_s.strip
      return if normalized.blank?

      paragraphs = normalized.split(/\n{2,}/).map(&:squish).reject(&:blank?)
      bullets = paragraphs.first(EXPERT_BULLET_LIMIT).map do |section|
        "- #{truncate(section, EXPERT_BULLET_TRUNCATE)}"
      end
      bullets.join("\n")[0, EXPERT_TEXT_LIMIT]
    end

    def truncate(text, limit)
      return text if text.length <= limit
      "#{text[0, limit]}…"
    end
  end
end
