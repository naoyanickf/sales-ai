class ExpertKnowledge < ApplicationRecord
  ALLOWED_EXTENSIONS = %w[pdf ppt pptx doc docx xls xlsx csv txt md mp3 wav m4a mp4 mov].freeze
  MAX_FILE_SIZE = 1000.megabytes

  belongs_to :sales_expert
  belongs_to :uploader, class_name: "User", foreign_key: :upload_user_id

  has_one_attached :file, dependent: :purge_later

  validates :content_type, presence: true, length: { maximum: 40 }
  validates :file_name, presence: true
  validate :file_presence
  validate :file_type_allowlist
  validate :file_size_within_limit

  before_validation :sync_file_name

  delegate :workspace, to: :sales_expert

  private

  def sync_file_name
    self.file_name = file.filename.to_s if file.attached?
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
