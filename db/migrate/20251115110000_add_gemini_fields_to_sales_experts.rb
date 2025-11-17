class AddGeminiFieldsToSalesExperts < ActiveRecord::Migration[8.1]
  def change
    add_column :sales_experts, :gemini_store_id, :string
    add_column :sales_experts, :gemini_store_state, :string, null: false, default: "pending"
    add_column :sales_experts, :gemini_store_error, :text
    add_column :sales_experts, :gemini_store_synced_at, :datetime

    add_index :sales_experts, :gemini_store_id, unique: true
  end
end
