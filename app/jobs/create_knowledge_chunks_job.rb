class CreateKnowledgeChunksJob < ApplicationJob
  queue_as :default

  def perform(transcription_id)
    transcription = Transcription.find_by(id: transcription_id)
    return unless transcription
    ek = transcription.expert_knowledge
    chunker = KnowledgeChunker.new(transcription)
    chunks = chunker.create_chunks
    return if chunks.empty?

    KnowledgeChunk.where(expert_knowledge_id: ek.id).delete_all
    chunks.each do |ch|
      KnowledgeChunk.create!(
        expert_knowledge_id: ek.id,
        chunk_text: ch[:chunk_text],
        transcription_segment_ids: ch[:transcription_segment_ids],
        metadata: { source: 'transcription' }
      )
    end
  end
end
