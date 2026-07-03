class AddEmbeddingsPricingSupport < ActiveRecord::Migration[8.1]
  def change
    # Embeddings bill per input token with no output tokens (the output is a
    # vector), so a priced row can carry an input rate and no output rate.
    change_column_null :price_points, :output_per_mtok, true
    add_column :ai_models, :dimensions, :integer
  end
end
