class SalesExpert < ApplicationRecord
  attribute :is_active, :boolean, default: true

  belongs_to :product
  has_many :expert_knowledges, -> { order(created_at: :desc) }, dependent: :destroy
  has_many :chats, dependent: :nullify

  validates :name, presence: true, length: { maximum: 80 }
  validates :description, length: { maximum: 1_000 }, allow_blank: true

  delegate :workspace, to: :product

  enum :gemini_store_state, {
    pending: "pending",
    processing: "processing",
    ready: "ready",
    failed: "failed"
  }, prefix: true

  after_create_commit :provision_gemini_store_if_needed
  after_destroy_commit :delete_gemini_store_if_needed

  def gemini_store_available?
    gemini_store_state == 'ready' && gemini_store_id.present?
  end

  def gemini_store_display_name
    base = name.to_s.gsub(/[^0-9A-Za-z.\-]/, "_")
    "SalesExpert-#{id}-#{base}".truncate(80, omission: "")
  end

  def query_gemini_rag(query)
    normalized_query = query.to_s.squish
    raise ArgumentError, "query を指定してください" if normalized_query.blank?
    raise StandardError, "Gemini File Search が利用できません" unless GeminiFileSearchClient.configured?
    raise StandardError, "Gemini ストアが未準備です" unless gemini_store_available?

    GeminiFileSearchClient.new.generate_content_with_store(
      query: normalized_query,
      store_names: [gemini_store_id]
    )
  end

  def provision_gemini_store!
    raise StandardError, "Gemini File Search が利用できません" unless GeminiFileSearchClient.configured?
    return if gemini_store_available?

    update!(
      gemini_store_state: :processing,
      gemini_store_error: nil
    )

    client = GeminiFileSearchClient.new
    response = client.create_store(display_name: gemini_store_display_name)
    store_name = response["name"].to_s
    raise StandardError, "Gemini File Search が store 名を返しませんでした" if store_name.blank?

    update!(
      gemini_store_id: store_name,
      gemini_store_state: :ready,
      gemini_store_error: nil,
      gemini_store_synced_at: Time.current
    )
  end

  def delete_gemini_store!
    raise StandardError, "Gemini File Search が利用できません" unless GeminiFileSearchClient.configured?
    return if gemini_store_id.blank?

    client = GeminiFileSearchClient.new
    client.delete_store(gemini_store_id, force: true)
  end

  private

  def provision_gemini_store_if_needed
    return unless GeminiFileSearchClient.configured?

    provision_gemini_store!
  rescue => e
    Rails.logger.error("[Gemini] Failed to provision store for SalesExpert##{id}: #{e.class} #{e.message}")
    update_columns(
      gemini_store_state: :failed,
      gemini_store_error: e.message
    )
  end

  def delete_gemini_store_if_needed
    return unless GeminiFileSearchClient.configured?
    return if gemini_store_id.blank?

    delete_gemini_store!
  rescue => e
    Rails.logger.warn("[Gemini] Failed to delete store #{gemini_store_id} for SalesExpert##{id}: #{e.class} #{e.message}")
  end
end
