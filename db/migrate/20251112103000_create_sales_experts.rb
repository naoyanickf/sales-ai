class CreateSalesExperts < ActiveRecord::Migration[8.1]
  def change
    create_table :sales_experts do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :avatar_url
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end
  end
end
