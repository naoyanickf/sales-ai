class CreateTranscriptionSegments < ActiveRecord::Migration[8.1]
  def change
    create_table :transcription_segments do |t|
      t.references :transcription, null: false, foreign_key: true, index: true
      t.string :speaker_label
      t.string :speaker_name
      t.text :text
      t.float :start_time
      t.float :end_time
      t.float :confidence
      t.integer :sequence_number

      t.timestamps
    end

    add_index :transcription_segments, [:transcription_id, :sequence_number]
  end
end

