class AddNativePriceToPricePoints < ActiveRecord::Migration[8.1]
  def up
    add_column :price_points, :native_price_usd, :decimal, precision: 12, scale: 6

    change_column_null :price_points, :input_per_mtok, true
    change_column_null :price_points, :output_per_mtok, true
  end

  def down
    change_column_null :price_points, :output_per_mtok, false
    change_column_null :price_points, :input_per_mtok, false

    remove_column :price_points, :native_price_usd
  end
end
