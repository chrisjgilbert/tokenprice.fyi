class AiModel < ApplicationRecord
  # Trailing windows for the "% change over time" indicators, in display order.
  # A window is the price in effect that long ago vs. now; :launch spans
  # the whole history. Prices are a step function (a snapshot holds until the
  # next one), so "the price N days ago" is the latest snapshot on or before
  # that date — see #price_as_of.
  CHANGE_WINDOWS = [
    [ "30d",          30.days ],
    [ "90d",          90.days ],
    [ "1y",           1.year ],
    [ "Since launch", :launch ]
  ].freeze

  belongs_to :provider
  has_many :price_points, dependent: :destroy

  # Provenance of a model's data. Hand-curated rows are "manual" and are never
  # overwritten by an automated importer; rows the OpenRouter sync owns are
  # "openrouter". Plain string (not a strict enum) so new sources can be added
  # without a migration.
  MANUAL_SOURCE     = "manual"
  OPENROUTER_SOURCE = "openrouter"

  enum :tier, { frontier: "frontier", mid: "mid", small: "small" }, validate: true
  # active   — current, generally available
  # legacy   — superseded but still callable
  # suspended— access pulled (temporarily or pending review); shown but flagged
  # retired  — gone for good; hidden from listings
  enum :status, { active: "active", legacy: "legacy", suspended: "suspended", retired: "retired" }, validate: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :slug, presence: true, uniqueness: true
  validates :source, presence: true
  # Surfaces a friendly error instead of a DB-level RecordNotUnique when an admin
  # links a model to an OpenRouter id another row already owns.
  validates :openrouter_id, uniqueness: true, allow_nil: true

  before_validation :set_slug, on: :create
  before_validation :normalize_openrouter_id

  scope :listed, -> { where.not(status: "retired").where(id: PricePoint.select(:ai_model_id)) }
  scope :by_release, -> { order(Arel.sql("released_on IS NULL"), released_on: :desc) }
  scope :curated, -> { where(source: MANUAL_SOURCE) }
  scope :from_openrouter, -> { where(source: OPENROUTER_SOURCE) }

  # Pretty URLs: /models/claude-opus-4-8
  def to_param = slug

  # Most recent price snapshot — the "current" price.
  # Uses the in-memory association (via max_by) so an eager-loaded
  # `includes(:price_points)` isn't defeated by a fresh ordered query.
  def current_price
    @current_price ||= price_points.max_by(&:effective_on)
  end

  # Oldest price snapshot — the launch price.
  def launch_price
    @launch_price ||= price_points.min_by(&:effective_on)
  end

  # Drop the memoized current/launch prices. The importer calls this after
  # appending a snapshot in-process so a later read recomputes instead of
  # returning a stale memo.
  def forget_price_cache!
    @current_price = @launch_price = nil
  end

  def current_input  = current_price&.input_per_mtok
  def current_output = current_price&.output_per_mtok
  def current_cached_input = current_price&.cached_input_per_mtok

  # A fuller descriptive paragraph for meta tags and structured data, folding
  # the editorial facets into the lede when they're present.
  def long_description
    segments = [ description.presence ]
    segments << "Strengths: #{strengths}." if strengths.present?
    segments << "Best for: #{best_for}." if best_for.present?
    segments << "Limitations: #{limitations}." if limitations.present?
    segments.compact.join(" ").presence
  end

  # The price snapshot in effect on a given date — the latest one on or before
  # it, or nil if the model had no price yet. Uses the in-memory association so
  # an eager-loaded `includes(:price_points)` isn't defeated by a fresh query.
  def price_as_of(date)
    price_points.select { |pp| pp.effective_on <= date }.max_by(&:effective_on)
  end

  # One window's price move, both dimensions. Either percent is nil where
  # there's nothing to report.
  PriceChange = Data.define(:label, :input, :output)

  # The most recent price move for this model: the two consecutive snapshots
  # that bracket it, plus the % change in each dimension. `input`/`output` are
  # nil where that dimension didn't move.
  PriceMove = Data.define(:model, :from, :to, :input, :output) do
    def date = to.effective_on
  end

  # Percentage change in a price dimension (:input or :output) over a trailing
  # window (an ActiveSupport::Duration like 30.days) or since launch (:launch).
  # Negative means it got cheaper. The window is clamped to the model's history:
  # if it reaches back before launch, the launch price is the reference. Returns
  # nil when there's nothing to report — a single snapshot, or a flat price
  # across the window.
  def price_change_over(dimension, window)
    price_change_between(dimension, reference_price(window), current_price)
  end

  # Percentage change between launch and now (negative = cheaper). Input leads
  # the table because most workloads are input-heavy; output sits alongside it
  # wherever there's room to show both.
  def input_change_since_launch  = price_change_over(:input, :launch)
  def output_change_since_launch = price_change_over(:output, :launch)

  # One PriceChange per CHANGE_WINDOWS entry, in display order. The reference
  # snapshot is resolved once per window and shared across both dimensions.
  def price_changes
    CHANGE_WINDOWS.map do |label, window|
      reference = reference_price(window)
      PriceChange.new(
        label:  label,
        input:  price_change_between(:input, reference, current_price),
        output: price_change_between(:output, reference, current_price)
      )
    end
  end

  def price_changed?
    price_points.count > 1
  end

  # The latest price move across this model's history, or nil when there's
  # nothing to report: a single snapshot, or a most-recent change where neither
  # input nor output actually moved (a cached-only or flat manual entry). Uses
  # the in-memory association so an eager-loaded includes(:price_points) isn't
  # defeated by a fresh ordered query.
  def latest_price_move
    snapshots = price_points.sort_by(&:effective_on)
    return nil if snapshots.size < 2

    from, to = snapshots[-2], snapshots[-1]
    # A flat dimension reads as nil, not 0% — price_change_between gives 0.0 for
    # two distinct snapshots that happen to match, so an identical-price or
    # cached-only entry collapses to "no move" and is dropped below.
    input  = price_change_between(:input, from, to)&.nonzero?
    output = price_change_between(:output, from, to)&.nonzero?
    return nil if input.nil? && output.nil?

    PriceMove.new(model: self, from:, to:, input:, output:)
  end

  # Fuzzy match against name, provider and slug. Every word in the query must
  # be a substring of some search term, or — to forgive typos like
  # "antropic" — an in-order subsequence of a single word.
  def matches?(query)
    words = query.to_s.downcase.scan(/[a-z0-9]+/)
    words.all? do |word|
      search_words.any? { |term| term.include?(word) || subsequence_of?(word, term) } ||
        search_runs.any? { |run| run.include?(word) }
    end
  end

  private

  # The snapshot a window is measured against: the launch price for :launch or
  # a window that reaches back before launch, otherwise the price in effect that
  # long ago.
  def reference_price(window)
    return launch_price if window == :launch

    price_as_of(Date.current - window) || launch_price
  end

  # Shared core of the price-change figures: % move in one dimension from one
  # snapshot to another, or nil when the move is undefined or zero (missing
  # data, a zero base, or the same snapshot on both ends).
  def price_change_between(dimension, from_price, to_price)
    return nil if from_price.nil? || to_price.nil? || from_price == to_price

    from = from_price.public_send("#{dimension}_per_mtok")
    to   = to_price.public_send("#{dimension}_per_mtok")
    return nil if from.nil? || to.nil? || from.zero?

    (((to - from) / from) * 100).round(1)
  end

  def search_words
    @search_words ||= search_sources.flat_map { |s| s.scan(/[a-z0-9]+/) }.uniq
  end

  # Punctuation-stripped runs ("claudeopus48") catch queries that skip the
  # separators, like "gpt55". Substring-only: subsequence matching against
  # runs this long would let almost any short letter combo match.
  def search_runs
    @search_runs ||= search_sources.map { |s| s.gsub(/[^a-z0-9]/, "") }.uniq
  end

  def search_sources
    [ name, provider&.name, slug ].map { |s| s.to_s.downcase }
  end

  def subsequence_of?(needle, haystack)
    return false if needle.length < 3 || needle.length > haystack.length

    i = 0
    haystack.each_char { |c| i += 1 if c == needle[i] }
    i == needle.length
  end

  def set_slug
    self.slug ||= name&.parameterize
  end

  # Blank reads as "not linked": collapse "" to nil so clearing the field in the
  # admin unlinks the model (and the unique index doesn't reject a second blank).
  def normalize_openrouter_id
    self.openrouter_id = openrouter_id.presence
  end
end
