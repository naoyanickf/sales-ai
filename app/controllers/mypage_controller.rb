class MypageController < ApplicationController
  before_action :authenticate_user!

  def index
    @new_chat = current_workspace.chats.new(user: current_user)
    @initial_message = Message.new
    @products = load_chat_products
    @available_sales_experts = load_workspace_sales_experts
  end
end
