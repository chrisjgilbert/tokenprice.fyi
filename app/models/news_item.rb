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
end
