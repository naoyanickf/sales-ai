class CreateTranscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :transcriptions do |t|
      t.references :expert_knowledge, null: false, foreign_key: true, index: true
      t.text :full_text
      t.json :structured_data
      t.integer :speaker_count
      t.float :duration_seconds
      t.string :language, null: false, default: 'ja-JP'

      t.timestamps
    end
  end
end

