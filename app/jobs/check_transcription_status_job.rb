class CheckTranscriptionStatusJob < ApplicationJob
  queue_as :default

  def perform(transcription_job_id)
    job = TranscriptionJob.find_by(id: transcription_job_id)
    return unless job
    # Placeholder: poll external service and branch accordingly
  end
end

