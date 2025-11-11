class WorkspaceUser < ApplicationRecord
  belongs_to :workspace
  belongs_to :user

  before_create :set_joined_at

  enum :role, { admin: "admin", participant: "participant" }, validate: true

  validates :user_id, uniqueness: { scope: :workspace_id }

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end
end
