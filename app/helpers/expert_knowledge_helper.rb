module ExpertKnowledgeHelper
  MEDIA_EXTENSIONS = %w[mp3 wav m4a mp4 mov].freeze

  def media_knowledge?(knowledge)
    return false unless knowledge.file&.attached?
    ext = knowledge.file.filename.extension&.downcase
    MEDIA_EXTENSIONS.include?(ext)
  end

  def transcription_status_badge(knowledge)
    return nil unless media_knowledge?(knowledge)

    status = knowledge.transcription_status
    job = knowledge.transcription_job

    case status
    when 'pending'
      content_tag(:span, '書き起こし待機中', class: 'badge bg-secondary')
    when 'processing'
      text = '解析中…'
      text << " (開始: #{l(job.started_at, format: :short)})" if job&.started_at
      content_tag(:span, class: 'badge bg-info text-dark d-inline-flex align-items-center gap-1') do
        concat(content_tag(:span, '', class: 'spinner-border spinner-border-sm'))
        concat(text)
      end
    when 'completed'
      content_tag(:span, '書き起こし完了', class: 'badge bg-success')
    when 'failed'
      msg = job&.error_message&.truncate(40)
      label = '書き起こし失敗'
      label << ": #{msg}" if msg.present?
      content_tag(:span, label, class: 'badge bg-danger')
    else
      nil
    end
  end
end

