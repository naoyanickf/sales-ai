class SalesExpertsController < ApplicationController
  include ProductShowContext

  before_action :authenticate_user!
  before_action :set_product
  before_action :require_workspace_admin!
  before_action :set_sales_expert, only: :destroy

  def create
    @sales_expert = @product.sales_experts.new(sales_expert_params)

    if @sales_expert.save
      redirect_to product_path(@product), notice: "先輩営業マンを追加しました。"
    else
      prepare_product_show_context(@product)
      @can_manage_products = true
      render "products/show", status: :unprocessable_entity
    end
  end

  def destroy
    @sales_expert.destroy!
    redirect_to product_path(@product), notice: "先輩営業マンを削除しました。"
  end

  private

  def set_product
    @product = current_workspace.products.find(params[:product_id])
  end

  def set_sales_expert
    @sales_expert = @product.sales_experts.find(params[:id])
  end

  def sales_expert_params
    params.require(:sales_expert).permit(:name, :description, :avatar_url, :is_active)
  end
end
