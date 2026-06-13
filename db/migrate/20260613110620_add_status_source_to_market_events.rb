class AddStatusSourceToMarketEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :market_events, :status, :string, null: false, default: "published"
    add_column :market_events, :source, :string
    add_column :market_events, :source_url, :string
    add_index :market_events, :status
  end
end
