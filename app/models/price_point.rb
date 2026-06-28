class PricePoint < ApplicationRecord
  belongs_to :ai_model

  validates :effective_on, presence: true,
            uniqueness: { scope: :ai_model_id,
                          message: "already has a price on this date — edit that snapshot instead" }
  validates :input_per_mtok, :output_per_mtok,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 }
  validates :cached_input_per_mtok, :cache_write_per_mtok, :audio_input_per_mtok,
            :image_input_usd, :request_usd,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :chronological, -> { order(:effective_on) }
end
