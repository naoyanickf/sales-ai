# Usage: bundle exec rails runner sample2.rb <product_document_id>
require_relative "config/environment"

product_document_id = 1

document = ProductDocument.with_attached_file.find(product_document_id)
product  = document.product
store_id = "fileSearchStores/product-a-docs-9hvqzxnk86s2"

client = GeminiFileSearchClient.new

operation = document.file.open do |io|
  client.upload_file_to_store(
    store_name: store_id,
    io: io,
    filename: document.file.filename.to_s,
    mime_type: document.file.content_type || "application/octet-stream",
    display_name: document.document_name.presence || document.file.filename.to_s,
    custom_metadata: [
      { key: "product_document_id", stringValue: document.id.to_s },
      { key: "product_id",         stringValue: product.id.to_s },
      { key: "workspace_id",       stringValue: product.workspace_id.to_s }
    ],
    chunking_config: {
      "chunkSizeTokens"  => 512,
      "maxOverlapTokens" => 32
    },
    file_size: document.file.blob.byte_size
  )
end

loop do
  operation_name = operation['name'].split("/").last
  result = client.get_operation(store_id, operation_name)
  break if result["done"]
  sleep 5
end

puts "Uploaded ProductDocument ##{document.id} to #{store_id}"
