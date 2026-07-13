class CreateModelCandidates < ActiveRecord::Migration[8.1]
  def change
    create_table :model_candidates do |t|
      t.references :news_item, null: true, foreign_key: true
      t.string  :name,          null: false
      t.string  :provider_name, null: false
      t.string  :slug,          null: false
      t.string  :category_slug
      t.json    :pricing
      t.date    :released_on
      t.string  :source_url
      t.string  :confidence
      t.string  :rationale
      t.string  :status,        null: false, default: "pending"
      t.timestamps
    end
    add_index :model_candidates, :status
    add_index :model_candidates, :slug

    # Idempotency stamp for ModelCurationJob — parallel to news_items.curated_at
    # (the market-event bridge), so a release item is extracted for a model
    # candidate at most once regardless of run cadence.
    add_column :news_items, :curated_for_model_at, :datetime
    add_index  :news_items, :curated_for_model_at
  end
end
