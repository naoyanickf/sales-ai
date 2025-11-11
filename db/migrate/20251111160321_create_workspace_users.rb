class CreateWorkspaceUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :workspace_users do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "admin"
      t.datetime :joined_at, null: false

      t.timestamps
    end

    add_index :workspace_users, %i[workspace_id user_id], unique: true
  end
end
