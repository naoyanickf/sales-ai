class AddGeminiFieldsToProductsAndProductDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :gemini_data_store_id, :string
    add_column :products, :gemini_data_store_status, :string, null: false, default: "pending"
    add_column :products, :gemini_data_store_error, :text

    add_column :product_documents, :gemini_document_id, :string
    add_column :product_documents, :gemini_sync_status, :string, null: false, default: "pending"
    add_column :product_documents, :gemini_sync_error, :text
    add_column :product_documents, :gemini_operation_name, :string
    add_column :product_documents, :gemini_synced_at, :datetime

    add_index :products, :gemini_data_store_id, unique: true
    add_index :product_documents, :gemini_document_id, unique: true
  end
end
