class ProcessTranscriptionResultJob < ApplicationJob
  queue_as :default

  def perform(transcription_job_id)
    job = TranscriptionJob.find_by(id: transcription_job_id)
    return unless job
    # Placeholder: download results, create Transcription and segments
  end
end

