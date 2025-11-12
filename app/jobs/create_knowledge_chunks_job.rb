class CreateKnowledgeChunksJob < ApplicationJob
  queue_as :default

  def perform(transcription_id)
    transcription = Transcription.find_by(id: transcription_id)
    return unless transcription
    # Placeholder: invoke KnowledgeChunker and persist chunks
  end
end

