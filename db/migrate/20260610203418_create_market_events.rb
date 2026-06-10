class CreateMarketEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :market_events do |t|
      t.string :title, null: false
      t.date :event_date, null: false
      t.string :kind, null: false, default: "market"
      t.text :note

      t.timestamps
    end

    add_index :market_events, :event_date
    add_index :market_events, :kind
  end
end
