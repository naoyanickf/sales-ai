module TranscriptionHelper
  def format_duration(seconds)
    return "00:00" if seconds.nil?
    total = seconds.to_i
    minutes = total / 60
    secs = total % 60
    format("%02d:%02d", minutes, secs)
  end

  def format_speaker_label(label)
    return "不明な話者" if label.blank?
    if label.to_s =~ /spk[_-]?(\d+)/i
      idx = Regexp.last_match(1).to_i
      # A, B, C ...
      "話者" + ("A".ord + idx).chr
    else
      label.to_s
    end
  end

  def detect_file_format(filename)
    return nil if filename.blank?
    ext = File.extname(filename).delete(".").downcase
    case ext
    when 'mp3' then 'mp3'
    when 'wav' then 'wav'
    when 'm4a' then 'mp4' # Transcribe uses 'mp4' for m4a container
    when 'mp4' then 'mp4'
    when 'mov' then 'mov'
    else nil
    end
  end

  def calculate_confidence(items)
    return nil if items.blank?
    values = items.map { |i| i.respond_to?(:to_f) ? i.to_f : i.to_h.fetch('confidence', nil).to_f }.compact
    return nil if values.empty?
    (values.sum / values.size.to_f).round(3)
  end
end

