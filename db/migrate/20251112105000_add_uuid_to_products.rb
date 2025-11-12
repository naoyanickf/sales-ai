require "securerandom"

class AddUuidToProducts < ActiveRecord::Migration[8.1]
  class Product < ApplicationRecord
    self.table_name = "products"
  end

  def up
    add_column :products, :uuid, :string

    say_with_time "Backfilling UUIDs for existing products" do
      Product.reset_column_information
      Product.find_each do |product|
        product.update_columns(uuid: SecureRandom.uuid)
      end
    end

    change_column_null :products, :uuid, false
    add_index :products, :uuid, unique: true
  end

  def down
    remove_index :products, :uuid
    remove_column :products, :uuid
  end
end
