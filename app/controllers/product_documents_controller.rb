class ProductDocumentsController < ApplicationController
  include ProductShowContext
  before_action :authenticate_user!
  before_action :set_product
  before_action :require_workspace_admin!
  before_action :set_product_document, only: :destroy

  def create
    @product_document = @product.product_documents.new(product_document_params)
    @product_document.uploader = current_user

    if @product_document.save
      redirect_to product_path(@product), notice: "資料をアップロードしました。"
    else
      prepare_product_show_context(@product)
      @can_manage_products = true
      render "products/show", status: :unprocessable_entity
    end
  end

  def destroy
    @product_document.destroy!
    redirect_to product_path(@product), notice: "資料を削除しました。"
  end

  private

  def set_product
    @product = current_workspace.products.find(params[:product_id])
  end

  def set_product_document
    @product_document = @product.product_documents.find(params[:id])
  end

  def product_document_params
    params.require(:product_document).permit(:document_name, :document_type, :file)
  end
end
