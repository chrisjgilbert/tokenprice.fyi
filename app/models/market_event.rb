class MarketEvent < ApplicationRecord
  has_many :news_items, foreign_key: :market_event_id, dependent: :nullify

  validates :title,      presence: true
  validates :event_date, presence: true
  validates :kind,       presence: true, inclusion: { in: %w[market] }
  validates :status,     presence: true, inclusion: { in: %w[draft published] }

  scope :chronological, -> { order(event_date: :asc) }
  scope :recent_first,  -> { order(event_date: :desc) }
  scope :published,     -> { where(status: "published") }
  scope :drafts,        -> { where(status: "draft") }
  scope :listed,        -> { published.chronological }
end
