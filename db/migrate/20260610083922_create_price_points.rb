class CreatePricePoints < ActiveRecord::Migration[8.1]
  def change
    create_table :price_points do |t|
      t.references :ai_model, null: false, foreign_key: true
      t.date :effective_on, null: false
      t.decimal :input_per_mtok, precision: 12, scale: 6, null: false
      t.decimal :output_per_mtok, precision: 12, scale: 6, null: false
      t.decimal :cached_input_per_mtok, precision: 12, scale: 6
      t.string :source
      t.string :note

      t.timestamps
    end
    # One snapshot per model per date; also the index history charts query on.
    add_index :price_points, [ :ai_model_id, :effective_on ], unique: true
  end
end
