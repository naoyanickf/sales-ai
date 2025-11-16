class ProductDocumentsController < ApplicationController
  include ProductShowContext
  before_action :authenticate_user!
  before_action :set_product
  before_action :require_workspace_admin!, only: %i[create destroy]
  before_action :set_product_document, only: %i[show destroy]

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
  rescue ActiveRecord::RecordNotDestroyed => e
    Rails.logger.error("[ProductDocuments] Failed to destroy ProductDocument##{@product_document.id}: #{e.class} #{e.message}")
    alert_message = @product_document.errors.full_messages.to_sentence.presence || "資料の削除に失敗しました。"
    redirect_to product_path(@product), alert: alert_message
  end

  def show
    unless @product_document.file.attached?
      redirect_to product_path(@product), alert: "この資料にファイルがありません。"
      return
    end

    viewer = build_viewer_url(@product_document.file)
    if viewer[:mode] == :unsupported
      redirect_to rails_blob_path(@product_document.file, disposition: :attachment),
                  alert: "この形式はプレビューできません。ダウンロードしました。"
      return
    end

    @viewer_mode = viewer[:mode]
    @inline_url = viewer[:url]
  end

  private

  def set_product
    @product = current_workspace.products.find_by!(uuid: params[:product_id])
  end

  def set_product_document
    @product_document = @product.product_documents.find(params[:id])
  end

  def product_document_params
    params.require(:product_document).permit(:document_type, :file)
  end

  def build_viewer_url(file)
    extension = file.filename.extension&.downcase
    content_type = file.content_type.to_s

    if inline_supported_content?(content_type, extension)
      return {
        mode: :direct,
        url: rails_blob_path(file, disposition: :inline)
      }
    end

    if office_document_extension?(extension)
      absolute_url = rails_blob_url(file, disposition: :inline)
      viewer_url = "https://view.officeapps.live.com/op/embed.aspx?src=#{ERB::Util.url_encode(absolute_url)}"

      return {
        mode: :office,
        url: viewer_url
      }
    end

    { mode: :unsupported, url: nil }
  end

  def inline_supported_content?(content_type, extension)
    return true if content_type.start_with?("image/")
    return true if content_type == "application/pdf"
    return true if %w[txt md csv].include?(extension)

    false
  end

  def office_document_extension?(extension)
    %w[doc docx xls xlsx ppt pptx].include?(extension)
  end
end
