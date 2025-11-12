class WorkspacesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_workspace, only: %i[show update destroy]
  before_action :require_admin!, only: %i[update destroy]

  def new
    @workspace = Workspace.new
  end

  def create
    @workspace = Workspace.new(workspace_params)

    ActiveRecord::Base.transaction do
      @workspace.save!
      @workspace.workspace_users.create!(user: current_user, role: :admin)
      session[:current_workspace_id] = @workspace.id
    end

    redirect_to root_path, notice: "ワークスペースを作成しました。"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def show; end

  def update
    if @workspace.update(workspace_params)
      redirect_to workspace_path(@workspace), notice: "ワークスペース名を更新しました。"
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    if params[:confirm_name].to_s != @workspace.name
      @deletion_error = "確認のためにワークスペース名を正しく入力してください。"
      render :show, status: :unprocessable_entity
      return
    end

    @workspace.destroy!
    redirect_to authenticated_root_path, notice: "ワークスペースを削除しました。"
  end

  private

  def workspace_params
    params.require(:workspace).permit(:name)
  end

  def set_workspace
    @workspace = current_user.workspaces.find_by!(uuid: params[:uuid])
    @workspace_membership = @workspace.workspace_users.find_by!(user: current_user)
    @workspace_users = @workspace.workspace_users.includes(:user).order(:created_at)
    @pending_invitations = @workspace.workspace_invitations.pending.order(created_at: :desc)
    @new_invitation = WorkspaceInvitation.new
    session[:current_workspace_id] = @workspace.id
  end

  def require_admin!
    return if @workspace_membership&.admin?

    redirect_to root_path, alert: "ワークスペースの管理者のみアクセスできます。"
  end
end
