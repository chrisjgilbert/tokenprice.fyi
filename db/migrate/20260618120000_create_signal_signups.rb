class CreateSignalSignups < ActiveRecord::Migration[8.1]
  def change
    create_table :signal_signups do |t|
      # "measure_interest" — the primary demand signal for the measure product.
      # "price_alert"      — watch-this-price retention signal.
      t.string :kind, null: false
      t.string :email, null: false
      # Encoded workload / context the signup was captured against (opaque).
      t.text :payload

      t.timestamps
    end
    add_index :signal_signups, :kind
    add_index :signal_signups, :created_at
  end
end
