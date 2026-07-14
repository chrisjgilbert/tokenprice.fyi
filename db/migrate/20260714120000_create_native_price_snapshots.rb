class CreateNativePriceSnapshots < ActiveRecord::Migration[8.1]
  def up
    create_table :native_price_snapshots do |t|
      t.references :ai_model, null: false, foreign_key: true
      t.decimal :native_price_usd, precision: 12, scale: 6
      t.string :native_price_unit
      t.string :pricing_model
      t.string :price_summary
      t.string :price_source
      t.date :priced_as_of
      t.timestamps
    end
    add_index :native_price_snapshots, %i[ai_model_id created_at]

    # Backfill one snapshot per currently native-priced model, so the append-only
    # history starts from today's curated prices rather than empty — the first
    # deposit toward the directory tier's price record.
    model = Class.new(ActiveRecord::Base) { self.table_name = "ai_models" }
    snap  = Class.new(ActiveRecord::Base) { self.table_name = "native_price_snapshots" }
    model.reset_column_information
    model.where.not(price_summary: nil).or(model.where.not(native_price_usd: nil)).find_each do |m|
      snap.create!(
        ai_model_id: m.id,
        native_price_usd: m.native_price_usd, native_price_unit: m.native_price_unit,
        pricing_model: m.pricing_model, price_summary: m.price_summary,
        price_source: m.price_source, priced_as_of: m.priced_as_of,
        created_at: Time.current, updated_at: Time.current
      )
    end
  end

  def down
    drop_table :native_price_snapshots
  end
end
