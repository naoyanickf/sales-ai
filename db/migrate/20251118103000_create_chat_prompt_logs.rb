class CreateChatPromptLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_prompt_logs do |t|
      t.references :chat, null: false, foreign_key: true
      t.text :payload, size: :medium

      t.timestamps
    end

    add_index :chat_prompt_logs, [:chat_id, :created_at]
  end
end
