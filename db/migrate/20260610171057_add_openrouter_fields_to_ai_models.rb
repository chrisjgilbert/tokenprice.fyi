class AddOpenrouterFieldsToAiModels < ActiveRecord::Migration[8.1]
  def change
    # Where a model's data came from. Hand-curated rows stay "manual"; the daily
    # OpenRouter sync owns rows it creates ("openrouter"). Leaves room for more
    # automated sources later.
    add_column :ai_models, :source, :string, null: false, default: "manual"

    # The OpenRouter model id (e.g. "anthropic/claude-opus-4.5"). Unique key the
    # sync upserts against, and the link an admin can set on a curated model to
    # opt it into automated price enrichment.
    add_column :ai_models, :openrouter_id, :string

    add_index :ai_models, :source
    add_index :ai_models, :openrouter_id, unique: true
  end
end
