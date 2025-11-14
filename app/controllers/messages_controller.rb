class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_workspace!
  before_action :set_chat

  def create
    @message = @chat.messages.build(message_params.merge(role: :user))

    if @message.save
      Chats::AiResponseJob.perform_later(@chat.id)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to new_chat_path }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :error, status: :unprocessable_entity }
        format.html do
          redirect_to new_chat_path, alert: @message.errors.full_messages.to_sentence
        end
      end
    end
  end

  private

  def set_chat
    @chat = current_workspace.chats.find(params[:chat_id])
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
