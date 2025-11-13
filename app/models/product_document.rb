class ProductDocument < ApplicationRecord
  ALLOWED_EXTENSIONS = %w[pdf ppt pptx doc docx xls xlsx csv txt md].freeze
  MAX_FILE_SIZE = 300.megabytes

  belongs_to :product
  belongs_to :uploader, class_name: "User", foreign_key: :upload_user_id

  has_one_attached :file, dependent: :purge_later

  validates :document_name, presence: true, length: { maximum: 160 }
  validate :file_presence
  validate :file_type_allowlist
  validate :file_size_within_limit

  delegate :workspace, to: :product

  enum gemini_sync_status: {
    pending: "pending",
    queued: "queued",
    processing: "processing",
    synced: "synced",
    failed: "failed"
  }, _prefix: :gemini_sync

  after_commit :enqueue_gemini_sync, on: :create

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
end
