class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_workspace!
  before_action :set_chat
  before_action :load_chat_form_options, only: :create

  def create
    @message = @chat.messages.build(message_params.merge(role: :user))

    if @chat.messages.none?
      @message.errors.add(:base, "最初の質問はマイページトップから送信してください。")
      respond_to do |format|
        format.turbo_stream { render :error, status: :unprocessable_entity }
        format.html do
          redirect_to authenticated_root_path, alert: "マイページトップから最初の質問を送信してください。"
        end
      end
      return
    end

    unless @chat.product.present?
      @message.errors.add(:base, "製品を選択してください。")
      respond_to do |format|
        format.turbo_stream { render :error, status: :unprocessable_entity }
        format.html { redirect_to chat_path(@chat), alert: "製品を選択してください。" }
      end
      return
    end

    if @message.save
      Chats::AiResponseJob.perform_later(@chat.id)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to chat_path(@chat) }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :error, status: :unprocessable_entity }
        format.html do
          redirect_to chat_path(@chat), alert: @message.errors.full_messages.to_sentence
        end
      end
    end
  end

  private

  def set_chat
    @chat = current_workspace.chats.find(params[:chat_id])
  end

  def load_chat_form_options
    @products = load_chat_products
    @sales_experts = load_sales_experts_for(@chat.product_id)
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
