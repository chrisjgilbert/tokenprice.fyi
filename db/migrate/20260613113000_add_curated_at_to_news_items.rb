class AddCuratedAtToNewsItems < ActiveRecord::Migration[8.1]
  def change
    # Set once EventCurationJob has fed an item to the curator, so daily runs
    # never re-present the same item (and risk a duplicate draft).
    add_column :news_items, :curated_at, :datetime
    add_index :news_items, :curated_at
  end
end
