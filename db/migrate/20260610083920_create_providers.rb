class CreateProviders < ActiveRecord::Migration[8.1]
  def change
    create_table :providers do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :website
      t.string :accent, comment: "Hex accent colour used in the UI"

      t.timestamps
    end
    add_index :providers, :slug, unique: true
  end
end
