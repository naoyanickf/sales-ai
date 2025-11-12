class RemoveFileFromProductDocuments < ActiveRecord::Migration[8.1]
  def change
    remove_column :product_documents, :file, :string
  end
end
