class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :category
      t.boolean :is_active, null: false, default: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :products, %i[workspace_id name]
    add_index :products, :deleted_at
  end
end
