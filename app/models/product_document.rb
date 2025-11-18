class ProductDocument < ApplicationRecord
  ALLOWED_EXTENSIONS = %w[pdf ppt pptx doc docx xls xlsx csv txt md].freeze
  MAX_FILE_SIZE = 30.megabytes

  belongs_to :product
  belongs_to :uploader, class_name: "User", foreign_key: :upload_user_id

  has_one_attached :file, dependent: :purge_later

  before_validation :assign_document_name_from_file, on: :create

  validates :document_name, presence: true, length: { maximum: 160 }
  validate :file_presence
  validate :file_type_allowlist
  validate :file_size_within_limit

  delegate :workspace, to: :product

  enum :gemini_sync_status, {
    pending: "pending",
    queued: "queued",
    processing: "processing",
    synced: "synced",
    failed: "failed"
  }, prefix: :gemini_sync

  after_commit :enqueue_gemini_sync, on: :create
  before_destroy :remove_from_gemini_file_search

  private

  def enqueue_gemini_sync
    return unless GeminiFileSearchClient.configured?

    update_columns(
      gemini_sync_status: self.class.gemini_sync_statuses[:queued],
      gemini_sync_error: nil
    )
    Gemini::SyncProductDocumentJob.perform_later(id)
  end

  def file_presence
    errors.add(:file, "を選択してください") unless file.attached?
  end

  def file_type_allowlist
    return unless file.attached?

    extension = file.filename.extension&.downcase
    return if extension.present? && ALLOWED_EXTENSIONS.include?(extension)

    errors.add(:file, "は対応していない形式です")
  end

  def file_size_within_limit
    return unless file.attached?

    if file.byte_size > MAX_FILE_SIZE
      max_mb = MAX_FILE_SIZE / 1.megabyte
      errors.add(:file, "のサイズが大きすぎます（最大 #{max_mb}MB）")
    end
  end

  def remove_from_gemini_file_search
    return unless GeminiFileSearchClient.configured?

    store_id = product&.gemini_data_store_id
    document_id = gemini_document_id
    return if store_id.blank? || document_id.blank?

    GeminiFileSearchClient.new.delete_document(
      store_name: store_id,
      document_id: document_id,
      force: true
    )
  rescue GeminiFileSearchClient::Error => e
    return if e.status.to_i == 404

    errors.add(:base, "Gemini File Search からの削除に失敗しました: #{e.message}")
    throw :abort
  end

  def assign_document_name_from_file
    return if document_name.present?
    return unless file.attached?

    self.document_name = file.filename.to_s
  end
end
