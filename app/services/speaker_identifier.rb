class SpeakerIdentifier
  SALES_KEYWORDS = %w[弊社 ご提案 連携 導入 契約 見積 料金 価格 プラン 機能 事例 資料 サポート お打ち合わせ 日程 フォロー NDA 稟議].freeze
  CUSTOMER_KEYWORDS = %w[予算 社内 稟議 現状 課題 検討 確認 要件 問題 相談 比較 導入時期].freeze

  # Returns mapping { speaker_label => speaker_name }
  def identify(transcription)
    groups = transcription.segments.group_by(&:speaker_label)
    return {} if groups.empty?

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

    mapping = {}
    groups.keys.each do |label|
      mapping[label] = (label == sales_label ? '先輩営業' : '顧客')
    end
    mapping
  end
end
