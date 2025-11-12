class Workspace < ApplicationRecord
  acts_as_paranoid

  has_many :workspace_users, dependent: :destroy
  has_many :users, through: :workspace_users
  has_many :workspace_invitations, dependent: :destroy

  before_validation :set_uuid, on: :create

  validates :name, presence: true, length: { maximum: 80 }
  validates :uuid, presence: true, uniqueness: true

  def to_param
    uuid
  end

  private

  def set_uuid
    self.uuid ||= SecureRandom.uuid
  end
end
