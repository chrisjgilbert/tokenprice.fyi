class AddSoWhatToMarketEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :market_events, :so_what, :text
    add_column :market_events, :so_what_generated_at, :datetime
    # Citations backing the so_what: an array of { "url" =>, "title" => } hashes,
    # surfaced as links alongside the insight. Defaults to an empty array so reads
    # never have to nil-guard.
    add_column :market_events, :citations, :json, default: [], null: false
  end
end
