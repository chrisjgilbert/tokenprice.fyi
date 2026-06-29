class PricePoint < ApplicationRecord
  belongs_to :ai_model, touch: true

  validates :effective_on, presence: true,
            uniqueness: { scope: :ai_model_id,
                          message: "already has a price on this date — edit that snapshot instead" }
  validates :input_per_mtok, :output_per_mtok,
            :cached_input_per_mtok, :cache_write_per_mtok, :audio_input_per_mtok,
            :image_input_usd, :request_usd,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :text_rates_present_together
  validate :prices_something

  scope :chronological, -> { order(:effective_on) }

  private

  # A snapshot carries both per-token rates or neither. One without the other is a
  # half-entered price.
  def text_rates_present_together
    return if input_per_mtok.blank? == output_per_mtok.blank?

    errors.add(:base, "input and output per-token rates must be set together")
  end

  # A snapshot has to price something: the per-token pair.
  def prices_something
    return if input_per_mtok.present?

    errors.add(:base, "set per-token rates")
  end
end
