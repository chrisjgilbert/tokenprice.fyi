class AddAnnouncedAtToMarketEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :market_events, :announced_at, :datetime
  end
end
