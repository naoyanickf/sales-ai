class WorkspaceSwitchesController < ApplicationController
  before_action :authenticate_user!

  def create
    workspace = current_user.workspaces.find_by!(uuid: params[:workspace_uuid])
    session[:current_workspace_id] = workspace.id
    redirect_to workspace_path(workspace), notice: "#{workspace.name} に切り替えました。"
  end
end
