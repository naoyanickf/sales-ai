class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_product, only: %i[show edit update destroy]
  before_action :require_workspace_admin!, except: %i[index show]

  def index
    @products = current_workspace.products.order(:name)
    @can_manage_products = current_workspace_membership&.admin?
  end

  def show
    @product_documents = @product.product_documents.order(created_at: :desc)
    @product_document = ProductDocument.new
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

  private

  def set_product
    @product = current_workspace.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :category, :is_active)
  end
end
