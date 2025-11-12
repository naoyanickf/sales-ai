class KnowledgeChunk < ApplicationRecord
  belongs_to :expert_knowledge

  validates :chunk_text, presence: true

  before_save :ensure_metadata_structure

  private

  def ensure_metadata_structure
    self.metadata ||= {}
  end
end

