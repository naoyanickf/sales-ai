class ProcessTranscriptionResultJob < ApplicationJob
  queue_as :default

  require 'json'
  require 'open-uri'

  def perform(transcription_job_id, transcript_file_uri = nil)
    job = TranscriptionJob.find_by(id: transcription_job_id)
    return unless job

    data = fetch_transcript_json(transcript_file_uri)
    parsed = parse_transcribe_json(data)

    ActiveRecord::Base.transaction do
      t = Transcription.create!(
        expert_knowledge: job.expert_knowledge,
        full_text: parsed[:full_text],
        structured_data: parsed[:structured_data],
        speaker_count: parsed[:speaker_count],
        duration_seconds: parsed[:duration_seconds],
        language: parsed[:language] || 'ja-JP'
      )

      segments = parsed[:segments].presence || [
        { speaker_label: 'spk_0', text: parsed[:full_text].to_s, start_time: 0.0, end_time: nil, confidence: nil, sequence_number: 0 }
      ]
      segments.each_with_index do |seg, i|
        TranscriptionSegment.create!(
          transcription: t,
          speaker_label: seg[:speaker_label],
          speaker_name: seg[:speaker_name],
          text: seg[:text],
          start_time: seg[:start_time],
          end_time: seg[:end_time],
          confidence: seg[:confidence],
          sequence_number: seg[:sequence_number] || i
        )
      end

      job.expert_knowledge.update!(transcription_status: 'completed', transcription_completed_at: Time.current)

      CreateKnowledgeChunksJob.perform_later(t.id)
    end
  rescue => e
    job&.update!(status: 'failed', error_message: e.message)
    job&.expert_knowledge&.update!(transcription_status: 'failed')
    Rails.logger.error("ProcessTranscriptionResultJob failed: #{e.class} #{e.message}")
    raise
  end

  private

  def fetch_transcript_json(uri)
    return {} if uri.blank?
    body = URI.parse(uri).open.read
    JSON.parse(body)
  rescue => e
    Rails.logger.warn("Transcript fetch failed: #{e.class} #{e.message}")
    {}
  end

  def parse_transcribe_json(json)
    # Minimal parse: use full transcript, leave segments empty for now
    results = json['results'] || {}
    full_text = results.dig('transcripts', 0, 'transcript')
    language = json['language_code'] || 'ja-JP'
    speaker_count = results.dig('speaker_labels', 'speakers')
    duration_seconds = nil

    {
      full_text: full_text,
      structured_data: json,
      speaker_count: speaker_count,
      duration_seconds: duration_seconds,
      language: language,
      segments: []
    }
  end
end
