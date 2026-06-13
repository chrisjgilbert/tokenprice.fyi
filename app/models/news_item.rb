class NewsItem < ApplicationRecord
  belongs_to :market_event, optional: true

  validates :url,    presence: true
  validates :title,  presence: true
  validates :source, presence: true

  scope :pending_digest, -> { where(notified_at: nil).where("relevant = ? OR relevant IS NULL", true) }
  scope :recent,         -> { order(published_at: :desc) }
end
