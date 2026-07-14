# Native prices live as overwriting columns on ai_models (unlike per-token
# PricePoints, which append). This concern captures a dated snapshot whenever a
# native price column changes on a native-priced model, so a manual re-verify
# deposits history instead of destroying the previous value. Covers every write
# path — seeds, candidate acceptance, admin, console — with no caller changes.
module AiModel::NativePriceHistory
  extend ActiveSupport::Concern

  NATIVE_PRICE_COLUMNS = %w[
    native_price_usd native_price_unit pricing_model
    price_summary price_source priced_as_of
  ].freeze

  included do
    has_many :native_price_snapshots, dependent: :destroy
    after_save :append_native_price_snapshot, if: :native_price_recorded?
  end

  private

  # Append only when a native price column actually changed on this save AND the
  # model still carries a native price — a clear-out (price removed) records
  # nothing, and a non-price edit (description, name) records nothing.
  def native_price_recorded?
    (saved_changes.keys & NATIVE_PRICE_COLUMNS).any? && native_priced?
  end

  def append_native_price_snapshot
    native_price_snapshots.create!(
      native_price_usd:, native_price_unit:, pricing_model:,
      price_summary:, price_source:, priced_as_of:
    )
  end
end
