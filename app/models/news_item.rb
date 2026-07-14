class NewsItem < ApplicationRecord
  include Classifiable
  include Curatable

  belongs_to :market_event, optional: true

  has_many :model_candidates, dependent: :nullify

  validates :url,    presence: true
  validates :title,  presence: true
  validates :source, presence: true

  scope :pending_digest, -> { where(notified_at: nil).where("relevant = ? OR relevant IS NULL", true) }
  scope :recent,         -> { order(published_at: :desc) }
  # Relevant items not yet attached to an event and not yet seen by the curator.
  scope :awaiting_curation, -> { where(relevant: true, market_event_id: nil, curated_at: nil) }
  # Release-classified items not yet mined for a model candidate — the input to
  # the detection→curation bridge (ModelCurationJob).
  scope :awaiting_model_curation, -> { where(relevant: true, kind: "release", curated_for_model_at: nil) }

  # Generous relative to either LLM call that uses this — cheap on Haiku, and a
  # real digest's second or third story can sit deep in the body (see
  # NewsFeedFetcher::EXCERPT_MAX_CHARS, the separate cap on how much gets
  # stored at all).
  EXCERPT_CHARS_FOR_PROMPT = 20_000

  # A labeled excerpt block ready to append to an LLM prompt, or "" when there
  # is none — shared by NewsItem::Classification and NewsItem::ModelExtraction
  # so the truncation policy lives in one place.
  def excerpt_section
    text = excerpt.to_s.first(EXCERPT_CHARS_FOR_PROMPT)
    text.present? ? "\n\nExcerpt:\n#{text}" : ""
  end
end
