class ProductDocumentUploader < CarrierWave::Uploader::Base

  def store_dir
    workspace_id = model.product&.workspace_id || "workspace"
    product_id = model.product_id || "product"
    "uploads/workspaces/#{workspace_id}/products/#{product_id}"
  end

  def extension_allowlist
    %w[pdf ppt pptx doc docx xls xlsx csv txt md]
  end

  def size_range
    1.kilobyte..50.megabytes
  end

  def filename
    return unless original_filename.present?

    timestamp = Time.current.strftime("%Y%m%d%H%M%S")
    extension = File.extname(original_filename).downcase
    base = File.basename(original_filename, extension).parameterize(separator: "_")
    "#{timestamp}_#{base}#{extension}"
  end
end
