module ApplicationHelper
  include Turbo::FramesHelper
  include Turbo::StreamsHelper
  GEMINI_STORE_STATUS_LABELS = {
    "pending" => "未作成",
    "provisioning" => "作成中",
    "ready" => "利用可能",
    "failed" => "失敗"
  }.freeze

  GEMINI_SYNC_STATUS_LABELS = {
    "pending" => "待機中",
    "queued" => "同期待ち",
    "processing" => "同期中",
    "synced" => "同期済み",
    "failed" => "失敗"
  }.freeze

  def gemini_enabled?
    GeminiFileSearchClient.configured?
  end

  def gemini_store_status_badge(product)
    status = product.gemini_data_store_status
    return unless status

    label = GEMINI_STORE_STATUS_LABELS.fetch(status, status)
    css = case status
          when "ready" then "bg-success"
          when "failed" then "bg-danger"
          when "provisioning" then "bg-warning text-dark"
          else "bg-secondary"
          end
    tag.span(label, class: "badge #{css}")
  end

  def gemini_sync_status_badge(document)
    status = document.gemini_sync_status
    return unless status

    label = GEMINI_SYNC_STATUS_LABELS.fetch(status, status)
    css = case status
          when "synced" then "bg-success"
          when "failed" then "bg-danger"
          when "processing" then "bg-warning text-dark"
          when "queued" then "bg-info text-dark"
          else "bg-secondary"
          end
    tag.span(label, class: "badge #{css}")
  end

  # Convert plain URLs in text into clickable links.
  # - Escapes HTML first to avoid XSS
  # - Opens links in new tab with rel="noopener"
  def linkify_urls(text)
    return "" if text.blank?
    escaped = ERB::Util.html_escape(text.to_s)
    url_regex = %r{(https?://[^\s<]+)}
    linked = escaped.gsub(url_regex) do |url|
      %Q(<a href="#{url}" target="_blank" rel="noopener">#{url}</a>)
    end
    # Also linkify root-relative paths like /transcriptions/3#seg-123
    path_regex = %r{(^|[\s>])(/[^\s<]+)}
    linked = linked.gsub(path_regex) do
      prefix = Regexp.last_match(1)
      path = Regexp.last_match(2)
      # Avoid double-linking inside existing href attributes
      if prefix.ends_with?("=")
        "#{prefix}#{path}"
      else
        %Q(#{prefix}<a href="#{path}" target="_blank" rel="noopener">#{path}</a>)
      end
    end
    linked.html_safe
  end
end
