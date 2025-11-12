class Product < ApplicationRecord
  acts_as_paranoid

  belongs_to :workspace
  has_many :product_documents, dependent: :destroy
  has_many :sales_experts, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :category, length: { maximum: 80 }, allow_blank: true
  validates :uuid, presence: true, uniqueness: true

  scope :active, -> { where(is_active: true) }

  before_validation :assign_uuid, on: :create

  def status_badge
    is_active? ? "有効" : "無効"
  end

  def to_param
    uuid
  end

  private

  def assign_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
