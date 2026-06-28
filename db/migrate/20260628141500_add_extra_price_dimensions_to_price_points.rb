class AddExtraPriceDimensionsToPricePoints < ActiveRecord::Migration[8.1]
  # The extra cost dimensions OpenRouter exposes on text-output models, beyond
  # the three per-token rates. All nullable (nil = not charged), mirroring the
  # `cached_input_per_mtok` precedent.
  def change
    # Per-token, stored per 1M tokens (like input/output/cached).
    add_column :price_points, :cache_write_per_mtok, :decimal, precision: 12, scale: 6
    add_column :price_points, :audio_input_per_mtok, :decimal, precision: 12, scale: 6

    # Raw USD, NOT per-1M. OpenRouter's `image` is a per-input-image surcharge
    # for OpenAI/Anthropic but per-token on Google image rows — store the value
    # as quoted and label it "per input image"; revisit if the Google edge matters.
    add_column :price_points, :image_input_usd, :decimal, precision: 12, scale: 6
    # Flat per-request fee, raw USD.
    add_column :price_points, :request_usd, :decimal, precision: 12, scale: 6
  end
end
