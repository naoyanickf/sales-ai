class AddTranscriptionFieldsToExpertKnowledge < ActiveRecord::Migration[8.1]
  def change
    add_column :expert_knowledges, :transcription_status, :string, null: false, default: 'pending'
    add_column :expert_knowledges, :transcription_completed_at, :datetime
  end
end

