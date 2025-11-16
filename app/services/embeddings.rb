class Embeddings
  DEFAULT_MODEL = ENV.fetch('OPENAI_EMBEDDING_MODEL', 'text-embedding-3-small')

  def self.try_build
    return nil unless OpenAI.configuration.access_token.present?
    new
  rescue
    nil
  end

  def initialize(client: OpenAI::Client.new, model: DEFAULT_MODEL)
    @client = client
    @model = model
  end

  def embed(text)
    return nil if text.to_s.strip.empty?
    resp = @client.embeddings(parameters: { model: @model, input: text.to_s })
    Array(resp.dig('data')).first&.dig('embedding')
  rescue => e
    Rails.logger.warn("[Embeddings] failed: #{e.class} #{e.message}")
    nil
  end
end

