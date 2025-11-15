class TranscribeAudioJob < ApplicationJob
  queue_as :default

  def perform(expert_knowledge_id)
    expert = ExpertKnowledge.find_by(id: expert_knowledge_id)
    return unless expert

    expert.update!(transcription_status: 'processing')

    job = TranscriptionJob.create!(
      expert_knowledge: expert,
      status: 'processing',
      started_at: Time.current
    )

    # Start AWS Transcribe job if available
    begin
      s3_uri, media_format = s3_uri_and_format_for(expert)
      client = Aws::TranscribeService::Client.new
      job_name = "ek-#{expert.id}-#{Time.current.to_i}"
      resp = client.start_transcription_job(
        transcription_job_name: job_name,
        language_code: 'ja-JP',
        media_format: media_format,
        media: { media_file_uri: s3_uri },
        settings: { show_speaker_labels: true, max_speaker_labels: 5 }
      )
      external_id = resp.transcription_job.transcription_job_name
      job.update!(external_job_id: external_id)
      CheckTranscriptionStatusJob.set(wait: 30.seconds).perform_later(job.id)
    rescue NameError
      Rails.logger.warn("Aws SDK not available; leaving job in processing state")
    rescue => e
      job.update!(status: 'failed', error_message: e.message)
      expert.update!(transcription_status: 'failed')
      raise
    end
  rescue => e
    expert&.update!(transcription_status: 'failed')
    Rails.logger.error("TranscribeAudioJob failed: #{e.class} #{e.message}")
    raise
  end

  private

  def s3_uri_and_format_for(expert)
    raise 'No file attached' unless expert.file.attached?
    blob = expert.file.blob

    service = blob.service
    unless service.class.name.include?('S3')
      raise 'Active Storage is not configured for S3; Transcribe requires S3 media URI'
    end

    bucket = service.bucket.name
    key = blob.key
    ext = blob.filename.extension&.downcase
    media_format = case ext
                   when 'mp3' then 'mp3'
                   when 'wav' then 'wav'
                   when 'm4a' then 'mp4'
                   when 'mp4' then 'mp4'
                   when 'mov' then 'mov'
                   else
                     raise "Unsupported media format: #{ext}"
                   end
    ["s3://#{bucket}/#{key}", media_format]
  end
end
