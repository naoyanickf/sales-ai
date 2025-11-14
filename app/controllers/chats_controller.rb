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
    @new_chat = current_workspace.chats.new(user: current_user)
    @new_chat.assign_attributes(chat_params)
    @initial_message = Message.new(initial_message_params)
    @initial_message.content = @initial_message.content.to_s.strip
    @products = load_chat_products
    @sales_experts = load_sales_experts_for(@new_chat.product_id)
    @available_sales_experts = load_workspace_sales_experts

    validate_initial_chat_form

    if @new_chat.errors.any? || @initial_message.errors.any?
      render "mypage/index", status: :unprocessable_entity
      return
    end

    generated_title = Chats::TitleGenerator.new(content: @initial_message.content).call

    ActiveRecord::Base.transaction do
      @new_chat.title = generated_title if generated_title.present?
      @new_chat.save!
      session[:current_chat_id] = @new_chat.id
      @new_chat.messages.create!(role: :user, content: @initial_message.content)
    end

    Chats::AiResponseJob.perform_later(@new_chat.id)
    redirect_to chat_path(@new_chat), notice: "チャットを開始しました。"
  rescue ActiveRecord::RecordInvalid => e
    copy_record_errors(e.record)
    render "mypage/index", status: :unprocessable_entity
  end

  def update
    if @chat.update(chat_params)
      preload_context
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to chat_path(@chat), notice: "チャット設定を更新しました。" }
      end
    else
      preload_context
      respond_to do |format|
        format.turbo_stream { render status: :unprocessable_entity }
        format.html do
          redirect_to chat_path(@chat), alert: @chat.errors.full_messages.to_sentence
        end
      end
    end
  end

  private

  def set_chat_from_session
    session_chat_id = session[:current_chat_id]
    @chat = current_workspace.chats.find_by(id: session_chat_id) if session_chat_id.present?
    return if @chat.present?

    redirect_to authenticated_root_path, alert: "マイページトップから新しいチャットを開始してください。"
  end

  def set_chat
    @chat = current_workspace.chats.find(params[:id])
  end

  def chat_params
    params.require(:chat).permit(:title, :product_id, :sales_expert_id)
  end

  def initial_message_params
    message_params = params[:message] || params.dig(:chat, :message) || {}
    message_params = ActionController::Parameters.new(message_params) unless message_params.respond_to?(:permit)
    message_params.permit(:content)
  end

  def preload_context
    @message = Message.new
    @products = load_chat_products
    @sales_experts = load_sales_experts_for(@chat.product_id)
  end

  def validate_initial_chat_form
    if @new_chat.product_id.blank?
      @new_chat.errors.add(:product, "を選択してください。")
    end

    if @initial_message.content.blank?
      @initial_message.errors.add(:content, "を入力してください。")
    end
  end

  def copy_record_errors(record)
    return if record.nil?

    if record.is_a?(Message) && @initial_message
      record.errors.each { |error| @initial_message.errors.add(error.attribute, error.message) }
    elsif record.is_a?(Chat) && @new_chat
      record.errors.each { |error| @new_chat.errors.add(error.attribute, error.message) }
    end
  end
end
