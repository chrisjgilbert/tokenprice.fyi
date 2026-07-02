class AddCuratedPricingToAiModels < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_models, :pricing_model, :string
    add_column :ai_models, :price_summary, :string
    add_column :ai_models, :price_detail, :text
    add_column :ai_models, :price_source, :string
    add_column :ai_models, :priced_as_of, :date
  end
end
