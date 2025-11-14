class Product < ApplicationRecord
  acts_as_paranoid

  belongs_to :workspace
  has_many :product_documents, dependent: :destroy
  has_many :sales_experts, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :category, length: { maximum: 80 }, allow_blank: true
  validates :uuid, presence: true, uniqueness: true

  scope :active, -> { where(is_active: true) }

  enum :gemini_data_store_status, {
    pending: "pending",
    provisioning: "provisioning",
    ready: "ready",
    failed: "failed"
  }, prefix: :gemini_store

  before_validation :assign_uuid, on: :create
  after_commit :provision_gemini_data_store!, on: :create

  def status_badge
    is_active? ? "有効" : "無効"
  end

  def to_param
    uuid
  end

  def gemini_store_available?
    gemini_store_ready? && gemini_data_store_id.present?
  end

  def provision_gemini_data_store!
    return unless GeminiFileSearchClient.configured?
    return if gemini_store_available?

    update_columns(
      gemini_data_store_status: self.class.gemini_data_store_statuses[:provisioning],
      gemini_data_store_error: nil
    )

    response = GeminiFileSearchClient.new.create_store(display_name: gemini_store_display_name)
    store_name = response["name"].presence
    raise StandardError, "Gemini API did not return store name" if store_name.blank?

    update_columns(
      gemini_data_store_id: store_name,
      gemini_data_store_status: self.class.gemini_data_store_statuses[:ready],
      gemini_data_store_error: nil
    )
  rescue StandardError => e
    update_columns(
      gemini_data_store_status: self.class.gemini_data_store_statuses[:failed],
      gemini_data_store_error: e.message
    )
    Rails.logger.error("[Gemini] Failed to provision store for Product##{id}: #{e.class} #{e.message}")
    false
  end

  def query_gemini_rag(query)
    raise ArgumentError, "query を指定してください" if query.blank?
    raise StandardError, "Gemini File Search が利用できません" unless GeminiFileSearchClient.configured?
    raise StandardError, "Gemini データストアが未準備です" unless gemini_store_available?

    GeminiFileSearchClient.new.generate_content_with_store(
      query: query,
      store_names: [gemini_data_store_id]
    )
  end

  private

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end

  def gemini_store_display_name
    workspace_name = truncate_for_store(workspace&.name)
    product_name = truncate_for_store(name)
    base = "#{workspace_name.presence || 'Workspace'} / #{product_name.presence || 'Product'}"
    base[0, 512]
  end

  def truncate_for_store(value, limit = 250)
    string = value.to_s
    return string if string.length <= limit

    string[0, limit]
  end
end
