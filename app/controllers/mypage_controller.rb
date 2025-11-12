class MypageController < ApplicationController
  before_action :authenticate_user!

  def index
    @workspace_memberships = current_user.workspace_users.includes(:workspace).where(workspaces: { deleted_at: nil })
  end
end
