class CreateWorkspaces < ActiveRecord::Migration[8.1]
  def change
    create_table :workspaces do |t|
      t.string :uuid, null: false
      t.string :name, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :workspaces, :uuid, unique: true
  end
end
