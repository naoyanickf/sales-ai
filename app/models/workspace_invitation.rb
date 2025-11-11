class WorkspaceInvitation < ApplicationRecord
  ROLES = { participant: "participant" }.freeze
  STATUSES = { pending: "pending", accepted: "accepted", cancelled: "cancelled" }.freeze

  belongs_to :workspace
  belongs_to :inviter, class_name: "User"
  belongs_to :invited_user, class_name: "User", optional: true

  enum :role, ROLES, validate: true
  enum :status, STATUSES, validate: true

  before_validation :normalize_email
  before_validation :assign_token, on: :create

  validates :email, presence: true, length: { maximum: 255 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :workspace_id, presence: true
  validates :inviter_id, presence: true
  validate :ensure_not_already_member
  validates :email, uniqueness: { scope: :workspace_id, conditions: -> { where(status: :pending) }, message: "はすでに招待されています" }

  scope :pending, -> { where(status: :pending) }

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def accept!(user)
    return false unless pending?
    return false if expired?
    return false if workspace.nil? || workspace.deleted_at.present?

    transaction do
      membership = workspace.workspace_users.find_or_initialize_by(user: user)
      if membership.new_record?
        membership.role = role
        membership.save!
      end

      update!(status: :accepted, invited_user: user, accepted_at: Time.current)
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def assign_token
    self.token ||= SecureRandom.hex(20)
  end

  def ensure_not_already_member
    return if workspace.nil?

    existing_user = User.find_by(email: email)
    return if existing_user.nil?
    return unless workspace.workspace_users.exists?(user_id: existing_user.id)

    errors.add(:email, "は既にこのワークスペースのメンバーです")
  end
end
