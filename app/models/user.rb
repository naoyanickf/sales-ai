class User < ApplicationRecord
  acts_as_paranoid

  before_destroy :rewrite_email_for_soft_delete

  has_many :workspace_users, dependent: :destroy
  has_many :workspaces, through: :workspace_users
  has_many :sent_workspace_invitations,
           class_name: "WorkspaceInvitation",
           foreign_key: :inviter_id,
           inverse_of: :inviter,
           dependent: :nullify
  has_many :received_workspace_invitations,
           class_name: "WorkspaceInvitation",
           foreign_key: :invited_user_id,
           inverse_of: :invited_user,
           dependent: :nullify

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :confirmable

  private

  def rewrite_email_for_soft_delete
    return if email.to_s.include?("+deleted-at-")

    timestamp = Time.current.strftime("%Y-%m-%d-%H:%M:%S")
    new_email = "#{email}+deleted-at-#{timestamp}"
    now = Time.current

    update_columns(
      email: new_email,
      confirmation_token: nil,
      reset_password_token: nil,
      updated_at: now
    )
  end
end
