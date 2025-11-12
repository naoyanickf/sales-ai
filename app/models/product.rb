class Product < ApplicationRecord
  acts_as_paranoid

  belongs_to :workspace
  has_many :product_documents, dependent: :destroy
  has_many :sales_experts, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :category, length: { maximum: 80 }, allow_blank: true

  scope :active, -> { where(is_active: true) }

  def status_badge
    is_active? ? "有効" : "無効"
  end
end
