class TranscriptionJob < ApplicationRecord
  belongs_to :expert_knowledge

  enum :status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }, prefix: true

  validates :status, presence: true, inclusion: { in: statuses.keys }

  scope :active, -> { where(status: %w[pending processing]) }
  scope :failed, -> { where(status: 'failed') }
end

