require "net/http"
require "uri"
require "json"
require "securerandom"

# Minimal client for Google Gemini File Search Store APIs.
class GeminiFileSearchClient
  BASE_URL = "https://generativelanguage.googleapis.com/v1beta/".freeze
  UPLOAD_BASE_URL = "https://generativelanguage.googleapis.com/upload/v1beta/".freeze
  DEFAULT_TIMEOUT = 20
  DEFAULT_OPEN_TIMEOUT = 5

  class << self
    def configured?
      ENV["GOOGLE_AI_STUDIO_API_KEY"].present?
    end
  end

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
    get(store_resource(name))
  end

  def create_store(display_name:)
    post("fileSearchStores", body: { displayName: display_name })
  end

  def delete_store(name, force: false)
    params = force ? { force: true } : {}
    delete(store_resource(name), params: params)
  end

  # ---------------------------------------------------------------------------
  # FileSearchStore Documents

  def list_documents(store_name:, page_size: 10, page_token: nil)
    parent = store_resource(store_name)
    params = { pageSize: page_size, pageToken: page_token }.compact
    get("#{parent}/documents", params: params)
  end

  def get_document(store_name:, document_id:)
    get(document_resource(store_name: store_name, document_id: document_id))
  end

  def delete_document(store_name:, document_id:, force: false)
    params = force ? { force: true } : {}
    delete(document_resource(store_name: store_name, document_id: document_id), params: params)
  end

  def query_document(store_name:, document_id:, query:, results_count: 10, metadata_filters: nil)
    body = {
      query: query,
      resultsCount: results_count,
      metadataFilters: metadata_filters
    }.compact

    post("#{document_resource(store_name: store_name, document_id: document_id)}:query", body: body)
  end

  def generate_content_with_store(query:, store_names:, model: "gemini-2.5-flash")
    names = Array(store_names).map(&:to_s).reject(&:blank?)
    raise ArgumentError, "query を指定してください" if query.blank?
    raise ArgumentError, "store_names を指定してください" if names.blank?

    body = {
      contents: [
        {
          parts: [
            { text: query }
          ]
        }
      ],
      tools: [
        {
          file_search: { file_search_store_names: names }
        }
      ]
    }

    post("models/#{model}:generateContent", body: body)
  end

  # ---------------------------------------------------------------------------
  # Upload / Import

  def upload_file_to_store(store_name:, io:, filename:, mime_type:,
                           display_name: nil, chunking_config: nil, custom_metadata: nil,
                           file_size: nil)
    raise ArgumentError, "IO object is required" unless io

    size = determine_file_size(io, file_size)
    metadata = {
      displayName: display_name || File.basename(filename),
      mimeType: mime_type,
    }.compact

    upload_url = start_resumable_upload(
      store_resource(store_name),
      file_size: size,
      mime_type: mime_type,
      metadata: metadata
    )

    upload_resumable_file(upload_url, io, size)
  end

  def import_file(store_name:, file_name:, custom_metadata: nil, chunking_config: nil)
    body = {
      fileName: file_name,
      customMetadata: custom_metadata,
      chunkingConfig: chunking_config
    }.compact

    post("#{store_resource(store_name)}:importFile", body: body)
  end

  def get_operation(store_name, operation_name)
    name = "#{store_name}/operations/#{operation_name}"
    get(store_resource(name))
  end

  # ---------------------------------------------------------------------------

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

  def post_raw(path, base_url:, params:, body:, content_type:)
    request(Net::HTTP::Post, path, params: params, body: body, base_url: base_url, content_type: content_type, encode_json: false)
  end

  def request(http_class, path, params:, body: nil, base_url: BASE_URL, content_type: "application/json", encode_json: true)
    ensure_api_key!
    uri = build_uri(base_url, path, params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = timeout
    http.open_timeout = open_timeout

    request = http_class.new(uri)
    request["Accept"] = "application/json"
    request["x-goog-api-key"] = api_key
    request["Content-Type"] = content_type if content_type
    request.body = encode_json && body ? body.to_json : body

    response = http.request(request)
    parse_response(response)
  rescue Timeout::Error => e
    raise Error.new("Gemini API request timed out: #{e.message}")
  end

  def ensure_api_key!
    raise ArgumentError, "GOOGLE_AI_STUDIO_API_KEY is missing" if api_key.blank?
  end

  def build_uri(base_url, path, params)
    uri = URI.join(base_url, path)
    uri.query = URI.encode_www_form(params.compact) if params.present?
    uri
  end

  def store_resource(name)
    name.start_with?("fileSearchStores/") ? name : "fileSearchStores/#{name}"
  end

  def document_resource(store_name:, document_id:)
    raise ArgumentError, "document_id is required" if document_id.blank?

    return document_id if document_id.start_with?("fileSearchStores/")

    normalized = document_id.sub(%r{\Adocuments/}i, "")
    "#{store_resource(store_name)}/documents/#{normalized}"
  end

  def parse_response(response)
    body = response.body.presence && JSON.parse(response.body)
    return body || {} if response.is_a?(Net::HTTPSuccess)

    message = body&.dig("error", "message") || response.message
    raise Error.new(message, status: response.code, body: body)
  rescue JSON::ParserError
    raise Error.new("Gemini API returned invalid JSON", status: response.code, body: response.body)
  end

  def start_resumable_upload(store_name, file_size:, mime_type:, metadata:)
    uri = build_uri(UPLOAD_BASE_URL, "#{store_name}:uploadToFileSearchStore?key=#{api_key}", {})
    http = build_http(uri)
    request = Net::HTTP::Post.new(uri)
    request["X-Goog-Upload-Protocol"] = "resumable"
    request["X-Goog-Upload-Command"] = "start"
    request["X-Goog-Upload-Header-Content-Length"] = file_size.to_s
    request["X-Goog-Upload-Header-Content-Type"] = mime_type
    request["Content-Type"] = "application/json"
    request.body = metadata.to_json

    response = http.request(request)
    raise Error.new("Failed to initiate upload", status: response.code, body: response.body) unless response.is_a?(Net::HTTPSuccess)

    upload_url = response["x-goog-upload-url"]
    raise Error.new("x-goog-upload-url header missing") if upload_url.blank?

    upload_url
  end

  def upload_resumable_file(upload_url, io, file_size)
    uri = URI(upload_url)
    http = build_http(uri)
    request = Net::HTTP::Post.new(uri)
    request["x-goog-api-key"] = api_key
    request["X-Goog-Upload-Offset"] = "0"
    request["X-Goog-Upload-Command"] = "upload, finalize"
    request["Content-Length"] = file_size.to_s
    io.binmode if io.respond_to?(:binmode)
    io.rewind if io.respond_to?(:rewind)
    request.body_stream = io

    response = http.request(request)
    parse_response(response)
  end

  def determine_file_size(io, explicit_size)
    return explicit_size if explicit_size
    return io.size if io.respond_to?(:size) && io.size

    if io.respond_to?(:stat)
      stat_size = io.stat.size rescue nil
      return stat_size if stat_size
    end

    # fallback: read into memory
    data = io.read
    raise ArgumentError, "Unable to read IO for size" if data.nil?
    size = data.bytesize
    io.rewind if io.respond_to?(:rewind)
    size
  end

  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60
    http.open_timeout = 10
    http
  end
end
