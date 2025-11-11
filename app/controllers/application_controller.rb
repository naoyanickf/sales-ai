class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :ensure_workspace!

  private

  def ensure_workspace!
    return if skip_workspace_check?
    return if current_user.active_workspaces.exists?

    redirect_to new_workspace_path
  end

  def skip_workspace_check?
    return true unless user_signed_in?
    return true if devise_controller?
    return true if controller_path == "workspaces" && %w[new create].include?(action_name)

    false
  end
end
