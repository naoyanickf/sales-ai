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
    buffer_speakers = Set.new
    buffer_chars = 0
    max_chars = 1200
    max_segments = 30

    segments.each do |seg|
      raw = seg.text.to_s.strip
      next if raw.blank?
      speaker = seg.speaker_name.presence || seg.speaker_label.presence || '話者'
      text = "#{speaker}: #{raw}"
      next if text.blank?
      if buffer_chars + text.length > max_chars || buffer.size >= max_segments
        chunks << build_chunk(buffer, buffer_ids, buffer_speakers.to_a)
        buffer = []
        buffer_ids = []
        buffer_speakers = Set.new
        buffer_chars = 0
      end
      buffer << text
      buffer_ids << seg.id
      buffer_speakers << speaker
      buffer_chars += text.length + 1
    end

    chunks << build_chunk(buffer, buffer_ids, buffer_speakers.to_a) if buffer.any?
    chunks
  end

  private

  def build_chunk(texts, ids, speakers)
    {
      chunk_text: texts.join("\n"),
      transcription_segment_ids: ids,
      metadata: { speakers: speakers }
    }
  end
end
