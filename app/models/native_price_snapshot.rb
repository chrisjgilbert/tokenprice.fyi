# One dated capture of a model's native (non-token) price. Appended — never
# updated — each time a curated native price changes, so the manually maintained
# directory tier accumulates a price history the way the per-token tier does via
# PricePoint. See AiModel::NativePriceHistory.
class NativePriceSnapshot < ApplicationRecord
  belongs_to :ai_model

  scope :chronological, -> { order(:created_at) }
end
