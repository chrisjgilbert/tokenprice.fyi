class MarketEvent < ApplicationRecord
  validates :title, presence: true
  validates :event_date, presence: true
  validates :kind, presence: true, inclusion: { in: %w[market] }

  scope :chronological, -> { order(event_date: :asc) }
  scope :recent_first, -> { order(event_date: :desc) }
end
