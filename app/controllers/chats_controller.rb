class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_workspace!
  before_action :set_chat_from_session, only: %i[new]
  before_action :set_chat, only: %i[show update]

  def new
    preload_context
  end

  def show
    session[:current_chat_id] = @chat.id
    preload_context
    render :new
  end

  def create
    chat = current_workspace.chats.create!(user: current_user)
    session[:current_chat_id] = chat.id
    redirect_to new_chat_path, notice: "新しいチャットを開始しました。"
  end

  def update
    if @chat.update(chat_params)
      preload_context
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to new_chat_path, notice: "チャット設定を更新しました。" }
      end
    else
      preload_context
      respond_to do |format|
        format.turbo_stream { render status: :unprocessable_entity }
        format.html do
          redirect_to new_chat_path, alert: @chat.errors.full_messages.to_sentence
        end
      end
    end
  end

  private

  def set_chat_from_session
    session_chat_id = session[:current_chat_id]
    @chat = current_workspace.chats.find_by(id: session_chat_id)
    return if @chat.present?

    @chat = current_workspace.chats.create!(user: current_user)
    session[:current_chat_id] = @chat.id
  end

  def set_chat
    @chat = current_workspace.chats.find(params[:id])
  end

  def chat_params
    params.require(:chat).permit(:title, :product_id, :sales_expert_id)
  end

  def preload_context
    @message = Message.new
    @products = current_workspace.products.order(:name)
    @sales_experts = sales_experts_for(@chat.product_id)
  end

  def sales_experts_for(product_id)
    return SalesExpert.none unless product_id

    current_workspace.products.find_by(id: product_id)&.sales_experts&.where(is_active: true)&.order(:name) || SalesExpert.none
  end
end
