class KnowledgeTranscriptBundlerJob < ApplicationJob
  queue_as :default

  def perform(expert_knowledge_id)
    expert_knowledge = ExpertKnowledge.includes(transcription: :segments).includes(:sales_expert).find_by(id: expert_knowledge_id)
    return unless expert_knowledge

    transcription = expert_knowledge.transcription
    segments = transcription&.segments&.ordered
    return if segments.blank?

    text = build_txt(expert_knowledge, segments)

    file_record = expert_knowledge.expert_knowledge_file || expert_knowledge.build_expert_knowledge_file
    file_record.assign_attributes(
      txt_body: text,
      txt_generated_at: Time.current,
      segment_count: segments.size,
      gemini_file_status: :pending,
      gemini_file_error: nil,
      gemini_operation_name: nil
    )
    file_record.save!

    Gemini::SyncExpertKnowledgeFileJob.perform_later(file_record.id) if GeminiFileSearchClient.configured?
  end

  private

  def build_txt(expert_knowledge, segments)
    lines = []
    lines << "## Sales Expert Knowledge Transcript"
    lines << "Expert: #{expert_knowledge.sales_expert.name}"
    lines << "Original File: #{expert_knowledge.file_name}"
    lines << "Generated At: #{Time.current.utc.iso8601}"
    lines << "Segment Count: #{segments.size}"
    lines << ""
    segments.each do |segment|
      next if segment.text.blank?

      lines << format_segment(segment)
    end
    lines.join("\n").strip
  end

  def format_segment(segment)
    speaker = segment.speaker_name.presence || segment.speaker_label.presence || default_speaker(segment)
    "[#{format_time(segment.start_time)}-#{format_time(segment.end_time)}] #{speaker}: #{segment.text.to_s.squish}"
  end

  def default_speaker(segment)
    "Speaker#{segment.sequence_number}"
  end

  def format_time(value)
    return "--:--" if value.nil?

    total_seconds = value.to_f
    minutes = (total_seconds / 60).floor
    seconds = (total_seconds % 60).round
    format("%02d:%02d", minutes, seconds)
  end
end
