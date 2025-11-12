class CreateKnowledgeChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_chunks do |t|
      t.references :expert_knowledge, null: false, foreign_key: true, index: true
      t.json :transcription_segment_ids, default: []
      t.text :chunk_text
      t.json :metadata
      t.string :bedrock_data_source_id

      t.timestamps
    end
  end
end

