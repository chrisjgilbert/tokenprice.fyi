# Drops the native (per-unit) pricing the directory classes used and restores the
# per-token rates to NOT NULL. The site tracks token-priced models only, so every
# price point carries an input/output rate; the native_price_usd column and the
# nullable text rates were added solely for the now-removed directory classes.
class RevertDirectoryClassSupport < ActiveRecord::Migration[8.1]
  def up
    remove_column :price_points, :native_price_usd
    change_column_null :price_points, :input_per_mtok, false
    change_column_null :price_points, :output_per_mtok, false
  end

  def down
    add_column :price_points, :native_price_usd, :decimal, precision: 12, scale: 6
    change_column_null :price_points, :input_per_mtok, true
    change_column_null :price_points, :output_per_mtok, true
  end
end
