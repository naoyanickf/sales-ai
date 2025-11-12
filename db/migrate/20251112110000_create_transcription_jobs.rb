class CreateTranscriptionJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :transcription_jobs do |t|
      t.references :expert_knowledge, null: false, foreign_key: true
      t.string :external_job_id, index: true
      t.string :status, null: false, default: 'pending', index: true
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end
  end
end

