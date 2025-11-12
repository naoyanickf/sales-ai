class CreateProductDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :product_documents do |t|
      t.references :product, null: false, foreign_key: true
      t.string :document_name, null: false
      t.string :document_type
      t.string :file, null: false
      t.bigint :upload_user_id, null: false
      t.json :metadata

      t.timestamps
    end

    add_index :product_documents, :upload_user_id
    add_foreign_key :product_documents, :users, column: :upload_user_id
  end
end
