class HomeController < ApplicationController
  def index
    return unless user_signed_in?

    @workspace_memberships = current_user.workspace_users.includes(:workspace).where(workspaces: { deleted_at: nil })
  end
end
