class CheckTranscriptionStatusJob < ApplicationJob
  queue_as :default

  def perform(transcription_job_id)
    job = TranscriptionJob.find_by(id: transcription_job_id)
    return unless job
    begin
      client = Aws::TranscribeService::Client.new
      resp = client.get_transcription_job(transcription_job_name: job.external_job_id)
      status = resp.transcription_job.transcription_job_status # 'QUEUED'|'IN_PROGRESS'|'FAILED'|'COMPLETED'

      case status
      when 'QUEUED', 'IN_PROGRESS'
        self.class.set(wait: 30.seconds).perform_later(job.id)
      when 'COMPLETED'
        job.update!(status: 'completed', completed_at: Time.current)
        uri = resp.transcription_job.transcript.transcript_file_uri
        ProcessTranscriptionResultJob.perform_later(job.id, uri)
      when 'FAILED'
        job.update!(status: 'failed', error_message: resp.transcription_job.failure_reason)
        job.expert_knowledge.update!(transcription_status: 'failed')
      end
    rescue NameError
      Rails.logger.warn("Aws SDK not available; status check skipped")
    end
  end
end
