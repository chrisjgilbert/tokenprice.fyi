class NewsItem < ApplicationRecord
  include Classifiable

  belongs_to :market_event, optional: true

  validates :url,    presence: true
  validates :title,  presence: true
  validates :source, presence: true

  # The outlet that actually published the story — the host of the article URL.
  # `source` records only how we found the item ("hn" is HN Algolia search), so
  # the feed credits where the reader lands (e.g. "arstechnica.com"), not the
  # search that surfaced it. An HN-native post whose only URL is the discussion
  # thread resolves to "news.ycombinator.com", which is its real home; `source`
  # is the fallback only when the URL has no host or can't be parsed.
  def source_host
    host = URI.parse(url).host&.downcase&.delete_prefix("www.")
    host.presence || source
  rescue URI::InvalidURIError
    source
  end

  scope :pending_digest, -> { where(notified_at: nil).where("relevant = ? OR relevant IS NULL", true) }
  scope :recent,         -> { order(published_at: :desc) }
  # The public /news feed: classified-relevant items with a publish date, newest
  # first. Unclassified (relevant: nil) and irrelevant items never surface — only
  # the digest funnel (pending_digest) tolerates a nil relevance.
  scope :feed, -> { where(relevant: true).where.not(published_at: nil).order(published_at: :desc) }
  # Relevant items not yet attached to an event and not yet seen by the curator.
  scope :awaiting_curation, -> { where(relevant: true, market_event_id: nil, curated_at: nil) }
end
