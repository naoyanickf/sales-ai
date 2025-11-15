class TranscriptionParser
  def initialize(raw_json)
    @raw = raw_json
  end

  def parse
    # TODO: implement Transcribe JSON parsing
    { full_text: nil, segments: [] }
  end
end

