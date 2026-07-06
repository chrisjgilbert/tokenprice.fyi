class AddNativePriceToAiModels < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_models, :native_price_usd, :decimal, precision: 12, scale: 6
    add_column :ai_models, :native_price_unit, :string
  end
end
