class Transcription < ApplicationRecord
  belongs_to :expert_knowledge
  has_many :segments, class_name: 'TranscriptionSegment', dependent: :destroy
  has_many :knowledge_chunks, through: :expert_knowledge

  validates :language, presence: true
end

