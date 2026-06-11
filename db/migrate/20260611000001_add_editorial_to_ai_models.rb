class AddEditorialToAiModels < ActiveRecord::Migration[8.1]
  def change
    # Qualitative editorial that complements the short `description` lede and the
    # always-computed price insights. Kept as free text so it stays stable as
    # prices move — it describes what a model is for, not what it costs today.
    add_column :ai_models, :strengths, :text
    add_column :ai_models, :limitations, :text
    add_column :ai_models, :best_for, :text
  end
end
