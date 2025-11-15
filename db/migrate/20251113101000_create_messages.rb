class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.integer :role, null: false, default: 0
      t.text :content, null: false
      t.integer :response_number, null: false, default: 0

      t.timestamps
    end

    add_index :messages, %i[chat_id created_at]
  end
end
