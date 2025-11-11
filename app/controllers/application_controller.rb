class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :ensure_profile_name!
  before_action :ensure_workspace!

  private

  def ensure_profile_name!
    return if skip_profile_check?
    return if current_user.name.present?

    redirect_to new_profile_path
  end

  def ensure_workspace!
    return if skip_workspace_check?
    return if current_user.workspaces.exists?

    redirect_to new_workspace_path
  end

  def skip_profile_check?
    !user_signed_in? || devise_controller? || controller_path == "profiles"
  end

  def skip_workspace_check?
    return true unless user_signed_in?
    return true if devise_controller?
    return true if controller_path == "profiles"
    return true if controller_path == "workspaces" && %w[new create].include?(action_name)

    false
  end
end
