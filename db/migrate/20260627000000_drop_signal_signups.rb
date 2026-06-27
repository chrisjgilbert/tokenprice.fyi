class DropSignalSignups < ActiveRecord::Migration[8.1]
  def up
    drop_table :signal_signups
  end

  def down
    create_table :signal_signups do |t|
      t.string :kind, null: false
      t.string :email, null: false
      t.text :payload

      t.timestamps
    end
    add_index :signal_signups, :kind
    add_index :signal_signups, :created_at
  end
end
