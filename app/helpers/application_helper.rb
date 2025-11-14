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
end
