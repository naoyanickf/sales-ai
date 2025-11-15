class MypageController < ApplicationController
  before_action :authenticate_user!

  def index
    @new_chat = current_workspace.chats.new(user: current_user)
    @initial_message = Message.new
    @products = load_chat_products
    default_product_id = @products.first&.id
    @new_chat.product_id ||= default_product_id if default_product_id
    @available_sales_experts = load_workspace_sales_experts
  end
end
