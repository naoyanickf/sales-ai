class ProductsController < ApplicationController
  include ProductShowContext
  before_action :authenticate_user!
  before_action :set_product, only: %i[show edit update destroy preview]
  before_action :require_workspace_admin!, except: %i[index show preview]

  def index
    @products = current_workspace.products.order(:name)
    @can_manage_products = current_workspace_membership&.admin?
  end

  def show
    @product_document = ProductDocument.new
    @sales_expert = SalesExpert.new
    @expert_knowledge = ExpertKnowledge.new
    prepare_product_show_context(@product)
    @can_manage_products = current_workspace_membership&.admin?
  end

  def new
    @product = current_workspace.products.new
  end

  def create
    @product = current_workspace.products.new(product_params)
    if @product.save
      redirect_to product_path(@product), notice: "製品を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @product.update(product_params)
      redirect_to product_path(@product), notice: "製品を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy!
    redirect_to products_path, notice: "製品を削除しました。"
  end

  def preview
    @can_manage_products = current_workspace_membership&.admin?
    @query = params[:query].to_s.strip
    @gemini_available = @product.gemini_store_available? && GeminiFileSearchClient.configured?
    @gemini_response = nil
    @gemini_result_text = nil
    @gemini_error = nil

    return if @query.blank?

    unless @gemini_available
      @gemini_error = "Gemini File Search が利用できません。"
      return
    end

    begin
      @gemini_response = @product.query_gemini_rag(@query)
      @gemini_result_text = extract_preview_text(@gemini_response)
    rescue StandardError => e
      Rails.logger.error("[ProductPreview] Failed to query Gemini for Product##{@product.id}: #{e.class} #{e.message}")
      @gemini_error = e.message
    end
  end

  private

  def set_product
    @product = current_workspace.products.find_by!(uuid: params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :category, :is_active)
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
