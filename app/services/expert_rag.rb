class ExpertRag
  # Fetch top-N knowledge chunks for a selected sales_expert relevant to query.
  # 1) Rank by BM25
  # 2) Optionally re-rank top_k by cosine similarity with OpenAI embeddings
  def self.fetch(sales_expert:, query:, limit: 5, rerank_top_k: 10)
    return [] if sales_expert.nil? || query.to_s.strip.empty?

    knowledge_ids = sales_expert.expert_knowledges.pluck(:id)
    return [] if knowledge_ids.empty?

    chunks = KnowledgeChunk.where(expert_knowledge_id: knowledge_ids).to_a
    return [] if chunks.empty?

    tokens = tokenize(query)
    corpus = chunks.map { |c| normalize(c.chunk_text) }
    bm25_scores = bm25_scores_for(tokens: tokens, corpus: corpus)

    prelim = chunks.each_with_index.map do |ch, idx|
      { id: ch.id, text: ch.chunk_text, score: bm25_scores[idx] }
    end
    prelim.select! { |h| h[:score] > 0 }
    prelim.sort_by! { |h| -h[:score] }

    reranked = re_rank_with_embeddings(query: query, hits: prelim.first(rerank_top_k))
    top = (reranked.presence || prelim).first(limit)

    Rails.logger.info("[ExpertRag] hits=#{top.size} chunks=#{chunks.size} tokens=#{tokens.size} query='#{query.to_s.truncate(40)}'")
    top
  end

  def self.normalize(text)
    text.to_s.strip
  end

  def self.tokenize(text)
    s = text.to_s.strip
    return [] if s.empty?
    # If the string contains CJK, prefer character n-grams to handle no-space texts
    if contains_cjk?(s)
      grams = char_ngrams(s, 3)
      return grams.uniq.first(100)
    end
    # Otherwise split by space/punct
    s.gsub(/[\p{Punct}\s]+/u, ' ').split.uniq.first(20)
  end

  # BM25 implementation over in-memory corpus
  def self.bm25_scores_for(tokens:, corpus:, k1: 1.2, b: 0.75)
    n = corpus.length.to_f
    lengths = corpus.map { |d| max(1, d.length) }
    avgdl = lengths.sum / n
    dfs = tokens.map do |t|
      df = corpus.count { |d| d.downcase.include?(t.downcase) }
      [t, df]
    end.to_h

    corpus.each_with_index.map do |doc, i|
      dl = lengths[i]
      score = 0.0
      tokens.each do |t|
        df = dfs[t].to_f
        next if df <= 0
        idf = Math.log((n - df + 0.5) / (df + 0.5) + 1)
        tf = term_frequency(doc, t)
        next if tf <= 0
        denom = tf + k1 * (1 - b + b * (dl / avgdl))
        score += idf * (tf * (k1 + 1)) / denom
      end
      score
    end
  end

  def self.term_frequency(doc, term)
    doc.downcase.scan(Regexp.new(Regexp.escape(term.downcase))).length
  end

  def self.max(a, b)
    a > b ? a : b
  end

  def self.re_rank_with_embeddings(query:, hits: [])
    return [] if hits.blank?
    embedder = Embeddings.try_build
    return nil unless embedder
    qv = embedder.embed(query)
    return nil unless qv
    hits.each do |h|
      v = embedder.embed(h[:text].to_s)
      sim = v ? cosine_similarity(qv, v) : 0.0
      h[:rerank] = sim
    end
    hits.sort_by { |h| -h[:rerank].to_f }
  rescue => e
    Rails.logger.warn("[ExpertRag] embedding rerank failed: #{e.class} #{e.message}")
    nil
  end

  def self.cosine_similarity(v1, v2)
    return 0.0 if v1.blank? || v2.blank? || v1.length != v2.length
    dot = 0.0
    n1 = 0.0
    n2 = 0.0
    v1.each_with_index do |x, i|
      y = v2[i]
      dot += x * y
      n1 += x * x
      n2 += y * y
    end
    denom = Math.sqrt(n1) * Math.sqrt(n2)
    denom > 0 ? dot / denom : 0.0
  end

  def self.contains_cjk?(s)
    # Hiragana, Katakana, Kanji ranges
    !!(s =~ /[\p{Hiragana}\p{Katakana}\p{Han}]/)
  end

  def self.char_ngrams(s, n)
    chars = s.gsub(/[\s\p{Punct}]+/u, '')
    return [chars] if chars.length <= n
    grams = []
    0.upto(chars.length - n) { |i| grams << chars[i, n] }
    grams
  end
end
