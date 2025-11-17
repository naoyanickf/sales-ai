require "securerandom"

class AddUuidToChats < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class MigrationChat < ApplicationRecord
    self.table_name = "chats"
  end

  def up
    add_column :chats, :uuid, :string
    add_index :chats, :uuid, unique: true

    MigrationChat.reset_column_information
    say_with_time("Backfilling chat uuids") do
      MigrationChat.find_each do |chat|
        chat.update_columns(uuid: SecureRandom.uuid_v7)
      end
    end

    change_column_null :chats, :uuid, false
  end

  def down
    remove_index :chats, :uuid
    remove_column :chats, :uuid
  end
end
