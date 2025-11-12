class CreateKnowledgeChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_chunks do |t|
      t.references :expert_knowledge, null: false, foreign_key: true, index: true
      # MySQL JSON columns cannot have a default value; set default in model callbacks
      t.json :transcription_segment_ids
      t.text :chunk_text
      t.json :metadata
      t.string :bedrock_data_source_id

      t.timestamps
    end
  end
end
