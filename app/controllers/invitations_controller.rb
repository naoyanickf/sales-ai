class InvitationsController < ApplicationController
  skip_before_action :ensure_profile_name!
  skip_before_action :ensure_workspace!
  before_action :set_invitation
  before_action :authenticate_user!

  def accept
    if @invitation.accept!(current_user)
      redirect_to workspace_path(@invitation.workspace), notice: "ワークスペースに参加しました。"
    else
      redirect_to root_path, alert: "この招待は使用できません。"
    end
  end

  private

  def set_invitation
    @invitation = WorkspaceInvitation.pending.find_by(token: params[:token])
    return if @invitation.present? && !@invitation.expired?

    redirect_to root_path, alert: "有効な招待が見つかりません。"
  end
end
