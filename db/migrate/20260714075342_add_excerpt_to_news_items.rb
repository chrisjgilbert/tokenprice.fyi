class AddExcerptToNewsItems < ActiveRecord::Migration[8.1]
  def change
    add_column :news_items, :excerpt, :text
  end
end
