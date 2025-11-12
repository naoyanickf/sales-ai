class CreateExpertKnowledges < ActiveRecord::Migration[8.1]
  def change
    create_table :expert_knowledges do |t|
      t.references :sales_expert, null: false, foreign_key: true
      t.string :content_type, null: false
      t.string :file_name, null: false
      t.json :metadata
      t.bigint :upload_user_id, null: false

      t.timestamps
    end

    add_foreign_key :expert_knowledges, :users, column: :upload_user_id
    add_index :expert_knowledges, :upload_user_id
  end
end
