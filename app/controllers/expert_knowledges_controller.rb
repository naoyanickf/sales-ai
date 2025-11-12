class ExpertKnowledgesController < ApplicationController
  include ProductShowContext

  before_action :authenticate_user!
  before_action :set_product
  before_action :require_workspace_admin!
  before_action :set_sales_expert
  before_action :set_expert_knowledge, only: :destroy

  def create
    @expert_knowledge = @sales_expert.expert_knowledges.new(expert_knowledge_params)
    @expert_knowledge.uploader = current_user

    if @expert_knowledge.save
      redirect_to product_path(@product), notice: "ナレッジをアップロードしました。"
    else
      @sales_expert_with_error = @sales_expert
      prepare_product_show_context(@product)
      @can_manage_products = true
      render "products/show", status: :unprocessable_entity
    end
  end

  def destroy
    @expert_knowledge.destroy!
    redirect_to product_path(@product), notice: "ナレッジを削除しました。"
  end

  private

  def set_product
    @product = current_workspace.products.find_by!(uuid: params[:product_id])
  end

  def set_sales_expert
    @sales_expert = @product.sales_experts.find(params[:sales_expert_id])
  end

  def set_expert_knowledge
    @expert_knowledge = @sales_expert.expert_knowledges.find(params[:id])
  end

  def expert_knowledge_params
    params.require(:expert_knowledge).permit(:content_type, :file)
  end
end
