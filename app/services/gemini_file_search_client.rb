require "net/http"
require "uri"
require "json"

# Minimal client for Google Gemini File Search Store APIs.
class GeminiFileSearchClient
  BASE_URL = "https://generativelanguage.googleapis.com/v1beta/".freeze
  DEFAULT_TIMEOUT = 20
  DEFAULT_OPEN_TIMEOUT = 5

  class Error < StandardError
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  def initialize(api_key: ENV.fetch("GOOGLE_AI_STUDIO_API_KEY", nil),
                 timeout: ENV.fetch("GEMINI_HTTP_TIMEOUT", DEFAULT_TIMEOUT).to_i,
                 open_timeout: ENV.fetch("GEMINI_HTTP_OPEN_TIMEOUT", DEFAULT_OPEN_TIMEOUT).to_i)
    raise ArgumentError, "GOOGLE_AI_STUDIO_API_KEY is missing" if api_key.blank?

    @api_key = api_key
    @timeout = timeout.positive? ? timeout : DEFAULT_TIMEOUT
    @open_timeout = open_timeout.positive? ? open_timeout : DEFAULT_OPEN_TIMEOUT
  end

  # FileSearchStore list/get/create/delete ------------------------------------

  def list_stores(page_size: 10, page_token: nil)
    params = { pageSize: page_size, pageToken: page_token }.compact
    get("fileSearchStores", params: params)
  end

  def get_store(name)
    get("fileSearchStores/#{name}")
  end

  def create_store(display_name:)
    post("fileSearchStores", body: { displayName: display_name })
  end

  def delete_store(name, force: false)
    params = force ? { force: true } : {}
    delete("fileSearchStores/#{name}", params: params)
  end

  private

  attr_reader :api_key, :timeout, :open_timeout

  def get(path, params: {})
    request(Net::HTTP::Get, path, params: params)
  end

  def post(path, body: nil, params: {})
    request(Net::HTTP::Post, path, params: params, body: body)
  end

  def delete(path, params: {})
    request(Net::HTTP::Delete, path, params: params)
  end

  def request(http_class, path, params:, body: nil)
    uri = build_uri(path, params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = timeout
    http.open_timeout = open_timeout

    request = http_class.new(uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request["x-goog-api-key"] = api_key
    request.body = body.to_json if body

    response = http.request(request)
    parse_response(response)
  rescue Timeout::Error => e
    raise Error.new("Gemini API request timed out: #{e.message}")
  end

  def build_uri(path, params)
    uri = URI.join(BASE_URL, path)
    uri.query = URI.encode_www_form(params.compact) if params.present?
    uri
  end

  def parse_response(response)
    body = response.body.presence && JSON.parse(response.body)
    return body || {} if response.is_a?(Net::HTTPSuccess)

    message = body&.dig("error", "message") || response.message
    raise Error.new(message, status: response.code, body: body)
  rescue JSON::ParserError
    raise Error.new("Gemini API returned invalid JSON", status: response.code, body: response.body)
  end
end
