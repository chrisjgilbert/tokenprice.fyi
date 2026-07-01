class AddSoWhatToAiModels < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_models, :so_what, :text
    add_column :ai_models, :so_what_generated_at, :datetime
  end
end
