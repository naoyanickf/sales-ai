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

      # Infer human-friendly speaker names (先輩営業/顧客)
      begin
        mapping = SpeakerIdentifier.new.identify(t)
        if mapping.present?
          t.segments.find_each do |seg|
            if mapping[seg.speaker_label]
              seg.update_column(:speaker_name, mapping[seg.speaker_label])
            end
          end
        end
      rescue => e
        Rails.logger.warn("Speaker identification skipped: #{e.class} #{e.message}")
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
    # Parse AWS Transcribe JSON into full_text and speaker segments
    results = json.to_h['results'] || {}
    full_text = results.dig('transcripts', 0, 'transcript')
    language = json['language_code'] || 'ja-JP'
    speaker_count = results.dig('speaker_labels', 'speakers')
    duration_seconds = nil

    items = Array(results['items'])
    words = []
    items.each do |it|
      type = it['type']
      alt = Array(it['alternatives']).first || {}
      content = alt['content']
      if type == 'pronunciation'
        words << {
          start_time: it['start_time']&.to_f,
          end_time: it['end_time']&.to_f,
          content: content,
          confidence: alt['confidence']&.to_f
        }
      else
        words << { punctuation: content }
      end
    end

    segments = []
    label_segments = Array(results.dig('speaker_labels', 'segments'))
    if label_segments.any? && words.any?
      label_segments.each_with_index do |seg, idx|
        s = seg['start_time'].to_f
        e = seg['end_time'].to_f
        label = seg['speaker_label'] || "spk_#{idx}"

        # collect words within time range
        content_words = words.select { |w| w[:start_time].to_f >= s && w[:end_time].to_f <= e && w[:content] }
        text = content_words.map { |w| w[:content] }.join(' ')
        # add simple punctuation if next is punctuation
        puncts = words.select { |w| w[:start_time].nil? && w[:punctuation] }
        text << puncts.map { |p| p[:punctuation] }.join if text.present?

        confs = content_words.map { |w| w[:confidence] }.compact
        avg_conf = confs.any? ? (confs.sum / confs.size) : nil

        segments << {
          speaker_label: label,
          speaker_name: nil,
          text: text,
          start_time: s,
          end_time: e,
          confidence: avg_conf,
          sequence_number: idx
        }
      end
    end

    {
      full_text: full_text,
      structured_data: json,
      speaker_count: speaker_count,
      duration_seconds: duration_seconds,
      language: language,
      segments: segments
    }
  end
end
