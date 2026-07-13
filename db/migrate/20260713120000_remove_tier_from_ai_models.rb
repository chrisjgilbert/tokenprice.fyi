class RemoveTierFromAiModels < ActiveRecord::Migration[8.1]
  def change
    remove_column :ai_models, :tier, :string, default: "frontier", null: false
  end
end
