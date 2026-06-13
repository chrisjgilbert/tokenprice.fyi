class CreateNewsItems < ActiveRecord::Migration[8.1]
  def change
    create_table :news_items do |t|
      t.string   :url,          null: false
      t.string   :title,        null: false
      t.string   :source,       null: false
      t.datetime :published_at
      t.string   :kind
      t.boolean  :relevant
      t.string   :rationale
      t.datetime :notified_at
      t.integer  :market_event_id
      t.timestamps
    end
    add_index :news_items, :url, unique: true
    add_index :news_items, :notified_at
    add_index :news_items, :published_at
  end
end
