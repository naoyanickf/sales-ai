class TranscriptionSegment < ApplicationRecord
  belongs_to :transcription

  validates :sequence_number, presence: true
  validates :text, presence: true

  scope :by_speaker, ->(label) { where(speaker_label: label) }
  scope :ordered, -> { order(:sequence_number) }
end

