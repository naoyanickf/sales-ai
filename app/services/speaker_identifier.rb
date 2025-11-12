class SpeakerIdentifier
  def identify(transcription)
    # TODO: infer speaker names using LLM
    transcription.segments.map do |seg|
      { id: seg.id, speaker_name: nil }
    end
  end
end

