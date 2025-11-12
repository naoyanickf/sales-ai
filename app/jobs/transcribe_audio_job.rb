class TranscribeAudioJob < ApplicationJob
  queue_as :default

  def perform(expert_knowledge_id)
    expert = ExpertKnowledge.find_by(id: expert_knowledge_id)
    return unless expert

    expert.update!(transcription_status: 'processing')

    TranscriptionJob.create!(
      expert_knowledge: expert,
      status: 'processing',
      started_at: Time.current
    )

    # TODO: Integrate with AWS Transcribe and schedule CheckTranscriptionStatusJob
  rescue => e
    expert&.update!(transcription_status: 'failed')
    Rails.logger.error("TranscribeAudioJob failed: #{e.class} #{e.message}")
    raise
  end
end

