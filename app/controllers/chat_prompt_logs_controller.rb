class ChatPromptLogsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_workspace!
  before_action :ensure_prompt_debug_enabled!
  before_action :set_chat

  def index
    @prompt_logs = @chat.prompt_logs.recent.limit(100)
  end

  private

  def set_chat
    @chat = current_workspace.chats.find_by!(uuid: params[:chat_id])
  end

  def ensure_prompt_debug_enabled!
    unless prompt_debug_enabled?
      redirect_to authenticated_root_path, alert: "Promptログは開発環境でのみ利用できます。"
    end
  end
end
