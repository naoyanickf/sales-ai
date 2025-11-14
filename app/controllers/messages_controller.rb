class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_workspace!
  before_action :set_chat
  before_action :assign_chat_context, only: :create
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

    if @chat.changed?
      unless @chat.save
        @chat.errors.full_messages.each { |error| @message.errors.add(:base, error) }
        respond_to do |format|
          format.turbo_stream { render :error, status: :unprocessable_entity }
          format.html { redirect_to chat_path(@chat), alert: @chat.errors.full_messages.to_sentence }
        end
        return
      end
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
    @available_sales_experts = load_workspace_sales_experts
  end

  def message_params
    params.require(:message).permit(:content)
  end

  def assign_chat_context
    return if params[:chat].blank?

    permitted = params.require(:chat).permit(:product_id, :sales_expert_id)
    permitted[:product_id] = permitted[:product_id].presence
    permitted[:sales_expert_id] = permitted[:sales_expert_id].presence
    @chat.assign_attributes(permitted)
  end
end
