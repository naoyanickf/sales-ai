class WorkspaceInvitationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :ensure_workspace_admin!

  def create
    @new_invitation = @workspace.workspace_invitations.build(invitation_params)
    @new_invitation.inviter = current_user

    if @new_invitation.save
      WorkspaceInvitationMailer.with(invitation: @new_invitation).invite_email.deliver_later
      redirect_to workspace_path(@workspace), notice: "招待メールを送信しました。"
    else
      prepare_workspace_context
      render "workspaces/show", status: :unprocessable_entity
    end
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find_by!(uuid: params[:workspace_uuid])
    @workspace_membership = @workspace.workspace_users.find_by!(user: current_user)
  end

  def ensure_workspace_admin!
    return if @workspace_membership.admin?

    redirect_to workspace_path(@workspace), alert: "招待できるのは管理者のみです。"
  end

  def invitation_params
    params.require(:workspace_invitation).permit(:email, :role)
  end

  def prepare_workspace_context
    @workspace_users = @workspace.workspace_users.includes(:user).order(:created_at)
    @pending_invitations = @workspace.workspace_invitations.pending.order(created_at: :desc)
    @new_invitation ||= WorkspaceInvitation.new
  end
end
