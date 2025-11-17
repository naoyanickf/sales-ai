class SalesExpertsController < ApplicationController
  include ProductShowContext

  before_action :authenticate_user!
  before_action :set_product
  before_action :require_workspace_admin!, except: :preview
  before_action :set_sales_expert, only: %i[edit update destroy preview]

  def create
    @sales_expert = @product.sales_experts.new(sales_expert_params)

    if @sales_expert.save
      redirect_to product_path(@product, tab: "sales_experts", anchor: "sales-experts-pane"),
                  notice: "先輩営業マンを追加しました。"
    else
      prepare_product_show_context(@product)
      @can_manage_products = true
      render "products/show", status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @sales_expert.update(sales_expert_params)
      redirect_to product_path(@product, tab: "sales_experts", anchor: "sales-experts-pane"),
                  notice: "先輩営業マンを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @sales_expert.destroy!
    redirect_to product_path(@product, tab: "sales_experts", anchor: "sales-experts-pane"),
                notice: "先輩営業マンを削除しました。"
  end

  def preview
    @can_manage_products = current_workspace_membership&.admin?
    @query = params[:query].to_s.strip
    @results = []
    @preview_error = nil
    @expert_knowledges = @sales_expert.expert_knowledges.includes(:transcription, :uploader, file_attachment: :blob)
    @knowledge_count = @expert_knowledges.size
    knowledge_ids = @expert_knowledges.map(&:id)
    @chunk_count = knowledge_ids.empty? ? 0 : KnowledgeChunk.where(expert_knowledge_id: knowledge_ids).count
    @recent_knowledge = @expert_knowledges.first

    return if @query.blank?

    begin
      hits = ExpertRag.fetch(sales_expert: @sales_expert, query: @query, limit: 5)
      chunk_map = KnowledgeChunk.includes(:expert_knowledge).where(id: hits.map { |h| h[:id] }).index_by(&:id)
      @results = hits.map do |hit|
        chunk = chunk_map[hit[:id]]
        knowledge = chunk&.expert_knowledge
        hit.merge(chunk: chunk, knowledge: knowledge)
      end
    rescue StandardError => e
      Rails.logger.error("[SalesExpertPreview] Failed ExpertRag fetch for SalesExpert##{@sales_expert.id}: #{e.class} #{e.message}")
      @preview_error = e.message
    end
  end

  private

  def set_product
    @product = current_workspace.products.find_by!(uuid: params[:product_id])
  end

  def set_sales_expert
    @sales_expert = @product.sales_experts.find(params[:id])
  end

  def sales_expert_params
    params.require(:sales_expert).permit(:name, :description, :is_active)
  end
end
