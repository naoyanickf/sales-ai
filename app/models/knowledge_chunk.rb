class KnowledgeChunk < ApplicationRecord
  belongs_to :expert_knowledge

  validates :chunk_text, presence: true

  before_validation :ensure_ids_array
  before_save :ensure_metadata_structure

  private

  def ensure_ids_array
    self.transcription_segment_ids ||= []
  end

  def ensure_metadata_structure
    self.metadata ||= {}
  end
end
