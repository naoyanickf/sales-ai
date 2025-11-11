class CreateWorkspaceInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :workspace_invitations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.references :invited_user, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :role, null: false, default: "participant"
      t.string :token, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :accepted_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :workspace_invitations, :token, unique: true
    add_index :workspace_invitations, [:workspace_id, :email, :status], name: "index_workspace_invites_on_workspace_email_status"
  end
end
