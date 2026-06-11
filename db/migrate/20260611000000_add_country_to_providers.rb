class AddCountryToProviders < ActiveRecord::Migration[8.1]
  def change
    # Where the provider is headquartered. `country_code` is the ISO 3166-1
    # alpha-2 code (e.g. "US", "CN", "FR") — the key the world map shades and
    # groups by; `country` is the human-readable name shown in the UI.
    add_column :providers, :country, :string
    add_column :providers, :country_code, :string

    add_index :providers, :country_code
  end
end
