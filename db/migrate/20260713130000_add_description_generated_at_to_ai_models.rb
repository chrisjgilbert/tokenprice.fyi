class AddDescriptionGeneratedAtToAiModels < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_models, :description_generated_at, :datetime
    add_index :ai_models, :description_generated_at
  end
end
