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
    @gemini_available = @sales_expert.gemini_store_available? && GeminiFileSearchClient.configured?
    @gemini_response = nil
    @gemini_result_text = nil
    @gemini_error = nil

    return if @query.blank?

    unless @gemini_available
      @gemini_error = "Gemini File Search が利用できません。"
      return
    end

    begin
      @gemini_response = @sales_expert.query_gemini_rag(@query)
      @gemini_result_text = extract_preview_text(@gemini_response)
    rescue StandardError => e
      @gemini_error = e.message
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

  def extract_preview_text(response)
    return if response.blank?

    hash_response = response.respond_to?(:to_h) ? response.to_h : response
    candidates = hash_response["candidates"] || hash_response[:candidates]
    parts = candidates&.first&.dig("content", "parts") || candidates&.first&.dig(:content, :parts)
    return if parts.blank?

    texts = parts.filter_map { |part| part["text"] || part[:text] }.map(&:to_s).map(&:strip).reject(&:blank?)
    texts.join("\n\n").presence
  rescue StandardError
    nil
  end
end
