class RemoveAvatarUrlFromSalesExperts < ActiveRecord::Migration[8.1]
  def change
    remove_column :sales_experts, :avatar_url, :string
  end
end
