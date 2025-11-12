class ProductDocument < ApplicationRecord
  belongs_to :product
  belongs_to :uploader, class_name: "User", foreign_key: :upload_user_id

  mount_uploader :file, ProductDocumentUploader

  validates :document_name, presence: true, length: { maximum: 160 }
  validates :file, presence: true

  delegate :workspace, to: :product
end
