class SpeakerIdentifier
  SALES_KEYWORDS = %w[弊社 ご提案 連携 導入 契約 見積 料金 価格 プラン 機能 事例 資料 サポート お打ち合わせ 日程 フォロー NDA 稟議].freeze
  CUSTOMER_KEYWORDS = %w[予算 社内 稟議 現状 課題 検討 確認 要件 問題 相談 比較 導入時期].freeze

  # Returns mapping { speaker_label => speaker_name }
  def identify(transcription)
    groups = transcription.segments.group_by(&:speaker_label)
    return {} if groups.empty?

    # 1) try LLM-based identification
    mapping = llm_identify(groups)
    return mapping if mapping.present?

    # 2) fallback: heuristic scoring
    heuristic_identify(groups)
  end

  private

  def llm_identify(groups)
    return {} unless OpenAI.configuration.access_token.present?
    client = OpenAI::Client.new
    system = <<~PROMPT
      あなたは会話の話者識別アシスタントです。日本語の商談ログの断片を読み、
      各話者ラベルが「先輩営業」か「顧客」かを判定してください。厳密なJSONのみを返してください。
      形式: {"mapping": {"spk_0": "先輩営業"|"顧客", ...}}
    PROMPT
    samples = groups.transform_values do |segs|
      segs.map { _1.text.to_s.squish }.reject(&:blank?).first(10).join("\n")
    end
    user = "話者ごとの発話サンプル:\n" + samples.map { |k,v| "#{k}: #{v}" }.join("\n\n")
    resp = client.chat(parameters: { model: 'gpt-4o-mini', messages: [
      { role: 'system', content: system },
      { role: 'user', content: user }
    ], temperature: 0.0 })
    content = resp.dig('choices',0,'message','content').to_s
    json = JSON.parse(content) rescue nil
    map = json.is_a?(Hash) ? json['mapping'] : nil
    return {} unless map.is_a?(Hash)
    # sanitize
    map.transform_values! { |v| v.to_s.include?('先輩') ? '先輩営業' : '顧客' }
    map
  rescue => e
    Rails.logger.warn("[SpeakerIdentifier] LLM identify failed: #{e.class} #{e.message}")
    {}
  end

  def heuristic_identify(groups)
    scores = {}
    groups.each do |label, segs|
      text = segs.map { _1.text.to_s }.join("\n").downcase
      sales_score = SALES_KEYWORDS.sum { |k| text.count(k.downcase) }
      cust_score = CUSTOMER_KEYWORDS.sum { |k| text.count(k.downcase) }
      length_score = text.length / 500.0
      scores[label] = sales_score * 3 + length_score - cust_score
    end
    sales_label = scores.max_by { |_, v| v }&.first
    return {} if sales_label.nil?
    groups.keys.index_with { |label| label == sales_label ? '先輩営業' : '顧客' }
  end
end
