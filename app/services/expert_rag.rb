class ExpertRag
  # Fetch top-N knowledge chunks for a selected sales_expert relevant to query.
  def self.fetch(sales_expert:, query:, limit: 5)
    return [] if sales_expert.nil? || query.to_s.strip.empty?

    knowledge_ids = sales_expert.expert_knowledges.pluck(:id)
    return [] if knowledge_ids.empty?

    chunks = KnowledgeChunk.where(expert_knowledge_id: knowledge_ids)
    return [] if chunks.empty?

    q = normalize(query)
    tokens = tokenize(q)
    scored = chunks.map do |ch|
      text = normalize(ch.chunk_text)
      score = score_text(text, tokens)
      next if score <= 0
      { id: ch.id, text: ch.chunk_text, score: score }
    end.compact

    scored.sort_by { |h| -h[:score] }.first(limit)
  end

  def self.normalize(text)
    text.to_s.strip
  end

  def self.tokenize(text)
    text.gsub(/[\p{Punct}\s]+/, ' ').split.uniq.first(15)
  end

  def self.score_text(text, tokens)
    return 0 if text.blank? || tokens.empty?
    lc = text.downcase
    tokens.sum { |t| lc.count(t.downcase) }
  end
end

