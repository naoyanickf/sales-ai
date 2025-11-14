class CreateChats < ActiveRecord::Migration[8.1]
  def change
    create_table :chats do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :product, foreign_key: true
      t.references :sales_expert, foreign_key: true
      t.string :title

      t.timestamps
    end

    add_index :chats, %i[workspace_id user_id created_at]
  end
end
