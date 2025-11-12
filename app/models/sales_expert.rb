class SalesExpert < ApplicationRecord
  attribute :is_active, :boolean, default: true

  belongs_to :product
  has_many :expert_knowledges, -> { order(created_at: :desc) }, dependent: :destroy

  validates :name, presence: true, length: { maximum: 80 }
  validates :description, length: { maximum: 1_000 }, allow_blank: true

  delegate :workspace, to: :product
end
