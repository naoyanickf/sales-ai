class ApplicationController < ActionController::Base
  include ChatContextLoader
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  before_action :basic_auth
  allow_browser versions: :modern
  layout :determine_layout
  before_action :ensure_profile_name!
  before_action :ensure_workspace!
  before_action :prepare_sidebar_context, if: :user_signed_in?

  helper_method :sidebar_memberships, :sidebar_recent_chats, :current_workspace, :current_workspace_membership

  private

  def basic_auth
    if Rails.env.production?
      authenticate_or_request_with_http_basic do |username, password|
        username == 'sales' && password == 'ai'
      end
    end
  end

  def determine_layout
    return "application" if !user_signed_in? || devise_controller?

    "authenticated"
  end

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
    !user_signed_in? || devise_controller? || controller_path == "profiles" || controller_path == "invitations"
  end

  def skip_workspace_check?
    return true unless user_signed_in?
    return true if devise_controller?
    return true if controller_path == "profiles"
    return true if controller_path == "invitations"
    return true if controller_path == "workspaces" && %w[new create].include?(action_name)

    false
  end

  def prepare_sidebar_context
    @sidebar_memberships = current_user.workspace_users.includes(:workspace).where(workspaces: { deleted_at: nil })
    @sidebar_recent_chats = load_recent_chats(limit: 10)
  end

  def sidebar_memberships
    @sidebar_memberships || []
  end

  def sidebar_recent_chats
    @sidebar_recent_chats || []
  end

  def current_workspace
    return nil unless user_signed_in?

    @current_workspace ||= begin
      selected_id = session[:current_workspace_id]
      scope = current_user.workspaces.where(workspaces: { deleted_at: nil })
      scope.find_by(id: selected_id) || scope.first
    end
  end

  def current_workspace_membership
    return nil unless user_signed_in?
    return nil if current_workspace.nil?

    @current_workspace_membership ||= begin
      sidebar_memberships.find { |membership| membership.workspace_id == current_workspace.id } ||
        current_user.workspace_users.find_by(workspace_id: current_workspace.id)
    end
  end

  def require_workspace_admin!
    return if current_workspace_membership&.admin?

    redirect_to authenticated_root_path, alert: "ワークスペースの管理者のみ操作できます。"
  end
end
