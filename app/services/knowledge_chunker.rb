class KnowledgeChunker
  def initialize(transcription)
    @transcription = transcription
  end

  def create_chunks
    segments = @transcription.segments.order(:sequence_number).to_a
    return [] if segments.empty?

    chunks = []
    buffer = []
    buffer_ids = []
    buffer_chars = 0
    max_chars = 1200
    max_segments = 30

    segments.each do |seg|
      text = seg.text.to_s.strip
      next if text.blank?
      if buffer_chars + text.length > max_chars || buffer.size >= max_segments
        chunks << build_chunk(buffer, buffer_ids)
        buffer = []
        buffer_ids = []
        buffer_chars = 0
      end
      buffer << text
      buffer_ids << seg.id
      buffer_chars += text.length + 1
    end

    chunks << build_chunk(buffer, buffer_ids) if buffer.any?
    chunks
  end

  private

  def build_chunk(texts, ids)
    {
      chunk_text: texts.join("\n"),
      transcription_segment_ids: ids
    }
  end
end
