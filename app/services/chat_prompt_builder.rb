class ChatPromptBuilder
  INTENT_GENERAL = :general
  INTENT_PRODUCT = :product
  PRODUCT_KEYWORDS = %w[価格 料金 金額 見積 プラン 契約 導入 比較 連携 費用 機能 制約 製品].freeze
  HISTORY_LIMIT = 10
  PRODUCT_TEXT_LIMIT = 3_000
  PRODUCT_BULLET_LIMIT = 5
  PRODUCT_BULLET_TRUNCATE = 280
  EXPERT_TEXT_LIMIT = 2_000
  EXPERT_RESPONSE_GROUP_LIMIT = 5
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
      あなたは礼儀正しく信頼できるB2B営業の相談アシスタントです。あなた自身が営業するのではなく、悩みを相談してきた営業担当が顧客に対して効果的に提案できるよう支援してください。
      事実ベースで回答し、
      - 推測は避け、根拠のない数値は出さない
      - 不明点は率直に伝える
      - 同僚や顧客を尊重した敬語で回答する
      - あなたの言葉を聞いた人が前向きな気持ちになるよう努める
      - あなたの言葉を聞いた人の行動を促すよう努める
    PROMPT
  end

  def context_message(product_text, expert_context: {})
    product_section = product_text.presence || PRODUCT_PLACEHOLDER
    expert_name = expert_context[:name].presence || "先輩営業未指定"
    expert_section = expert_context[:text].presence || EXPERT_PLACEHOLDER
    <<~CONTEXT.strip
      ## 製品情報
      #{product_section}

      ## 先輩営業のトーク履歴 (#{expert_name})
      #{expert_section}

      ## 会話履歴
      #{formatted_history}

      ユーザーからの最新相談:
      #{query}

      回答指針:
      1. 相談の意図を要約してから助言する
      2. 相談の内容に応じて、製品情報や先輩営業のトーク履歴を適宜参照し、適切な回答を行う
      3. 製品情報を参照した箇所は簡潔に根拠を示す
      4. 先輩営業のトーク履歴を参照した箇所は時系列、話者名、会話内容を省略せず、回答の末尾に示す
      5. 一般的な話などは求められていない場合しない
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
    PROMPT_TEMPLATE = <<~PROMPT.freeze
      次の文章は商談の記録です。「%{query}」に関して話している箇所を正確に抜き出してください。
      複数あればすべて列挙し、抜き出す際には会話の前後も含めてください。
      それぞれの抜粋には必ず以下を含めてください:
      - 時系列（例: 00:10-00:25）
      - 話者
      - 内容（実際の発話をそのまま引用する。省略や要約をしない）
    PROMPT

    def initialize(sales_expert, logger:)
      @sales_expert = sales_expert
      @logger = logger
    end

    def fetch(query)
      normalized_query = query.to_s.squish
      return empty_response if sales_expert.blank? || normalized_query.blank?

      response = sales_expert.query_gemini_rag(prompt_for(normalized_query))
      text = summarize(response)
      sources = extract_sources(response)

      { text: text, sources: sources, name: sales_expert_name }
    rescue StandardError => e
      logger.warn("[ChatPromptBuilder] Expert context fetch failed for SalesExpert##{sales_expert&.id}: #{e.class} #{e.message}")
      empty_response
    end

    private

    attr_reader :sales_expert, :logger

    def prompt_for(normalized_query)
      format(PROMPT_TEMPLATE, query: normalized_query)
    end

    def summarize(response)
      raw_text = extract_text(response)
      return if raw_text.blank?

      normalized = raw_text.to_s.strip
      return if normalized.blank?

      grouped = normalized.split(/\n{2,}/).reject(&:blank?).first(EXPERT_RESPONSE_GROUP_LIMIT)
      grouped.join("\n\n")[0, EXPERT_TEXT_LIMIT]
    end

    def extract_text(response)
      candidates = Array(response["candidates"])
      parts = candidates.flat_map { |candidate| Array(candidate.dig("content", "parts")) }
      texts = parts.map { |part| part["text"].to_s }.reject(&:blank?)
      texts.join("\n\n")
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

    def sales_expert_name
      sales_expert&.name.to_s
    end

    def empty_response
      { text: nil, sources: [], name: sales_expert_name }
    end
  end
end
