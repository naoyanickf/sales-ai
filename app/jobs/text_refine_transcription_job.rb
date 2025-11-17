class TextRefineTranscriptionJob < ApplicationJob
  queue_as :default

  def perform(transcription_id)
    transcription = Transcription.includes(:segments).find_by(id: transcription_id)
    return unless transcription

    refiner = JapaneseTextRefiner.new

    # 校正: 本文
    if transcription.full_text.present?
      refined = refiner.refine_text(transcription.full_text)
      transcription.update_column(:full_text, refined) if refined && refined != transcription.full_text
    end

    # 校正: セグメント
    transcription.segments.find_each do |seg|
      next if seg.text.blank?
      refined = refiner.refine_text(seg.text)
      next if refined.blank? || refined == seg.text
      seg.update_column(:text, refined)
    end

    KnowledgeTranscriptBundlerJob.perform_later(transcription.expert_knowledge_id) if transcription.expert_knowledge_id.present?
  rescue => e
    Rails.logger.error("TextRefineTranscriptionJob failed: #{e.class} #{e.message}")
    raise
  end
end
