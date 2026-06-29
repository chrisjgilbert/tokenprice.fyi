class AddDescriptionToProviders < ActiveRecord::Migration[8.1]
  def change
    add_column :providers, :description, :text
  end
end
