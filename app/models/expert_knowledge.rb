class ExpertKnowledge < ApplicationRecord
  ALLOWED_EXTENSIONS = %w[mp3 wav m4a mp4 mov].freeze
  # READMEに合わせてアップロード最大サイズは200MB
  MAX_FILE_SIZE = 200.megabytes

  belongs_to :sales_expert
  belongs_to :uploader, class_name: "User", foreign_key: :upload_user_id

  has_one_attached :file, dependent: :purge_later
  has_one :transcription_job, dependent: :destroy
  has_one :transcription, dependent: :destroy
  has_many :knowledge_chunks, dependent: :destroy
  has_one :expert_knowledge_file, dependent: :destroy

  validates :content_type, presence: true, length: { maximum: 40 }
  validates :file_name, presence: true
  validate :file_presence
  validate :file_type_allowlist
  validate :file_size_within_limit

  before_validation :sync_file_name
  after_create_commit :enqueue_transcription_if_media

  delegate :workspace, to: :sales_expert

  enum :transcription_status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }, prefix: true

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

  def enqueue_transcription_if_media
    return unless file.attached?

    extension = file.filename.extension&.downcase
    return unless %w[mp3 wav m4a mp4 mov].include?(extension)

    TranscribeAudioJob.perform_later(id)
  end
end
