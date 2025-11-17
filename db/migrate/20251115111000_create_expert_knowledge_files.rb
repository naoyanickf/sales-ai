class CreateExpertKnowledgeFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :expert_knowledge_files do |t|
      t.references :expert_knowledge, null: false, foreign_key: true
      t.text :txt_body, limit: 16.megabytes - 1
      t.datetime :txt_generated_at
      t.integer :segment_count, default: 0, null: false
      t.string :gemini_file_status, null: false, default: "pending"
      t.string :gemini_file_id
      t.string :gemini_file_uri
      t.string :gemini_operation_name
      t.text :gemini_file_error
      t.datetime :gemini_uploaded_at

      t.timestamps
    end

    add_index :expert_knowledge_files, :gemini_file_id, unique: true
  end
end
