class AddLastPromptPayloadToChats < ActiveRecord::Migration[8.1]
  def change
    add_column :chats, :last_prompt_payload, :text, size: :medium
  end
end
