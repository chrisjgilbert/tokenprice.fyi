class CreateAiModels < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_models do |t|
      t.references :provider, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :tier, null: false, default: "frontier", comment: "frontier | mid | small"
      t.integer :context_window
      t.integer :max_output_tokens
      t.date :released_on
      t.string :status, null: false, default: "active", comment: "active | legacy | retired"
      t.text :description

      t.timestamps
    end
    add_index :ai_models, :slug, unique: true
    add_index :ai_models, :tier
    add_index :ai_models, :status
  end
end
