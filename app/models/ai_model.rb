class AiModel < ApplicationRecord
  # A blended $/Mtok figure assumes this input:output token mix. It gives the
  # comparison table and "cheapest model" ranking a single sortable number.
  # Roughly models a chat/agent workload that reads more than it writes.
  BLEND_INPUT_WEIGHT = 3
  BLEND_OUTPUT_WEIGHT = 1

  # Trailing windows for the "% change over time" indicators, in display order.
  # A window is the blended price in effect that long ago vs. now; :launch spans
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
  enum :status, { active: "active", legacy: "legacy", retired: "retired" }, validate: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :slug, presence: true, uniqueness: true
  validates :source, presence: true

  before_validation :set_slug, on: :create

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

  # Single sortable number for ranking models against each other.
  def blended_per_mtok(price = current_price)
    return nil unless price

    total = BLEND_INPUT_WEIGHT + BLEND_OUTPUT_WEIGHT
    ((price.input_per_mtok * BLEND_INPUT_WEIGHT) +
     (price.output_per_mtok * BLEND_OUTPUT_WEIGHT)) / total
  end

  # The price snapshot in effect on a given date — the latest one on or before
  # it, or nil if the model had no price yet. Uses the in-memory association so
  # an eager-loaded `includes(:price_points)` isn't defeated by a fresh query.
  def price_as_of(date)
    price_points.select { |pp| pp.effective_on <= date }.max_by(&:effective_on)
  end

  # Percentage change in blended price over a trailing window (an
  # ActiveSupport::Duration like 30.days) or since launch (:launch). Negative
  # means it got cheaper. The window is clamped to the model's history: if it
  # reaches back before launch, the launch price is the reference. Returns nil
  # when there's nothing to report — a single snapshot, or a flat price across
  # the window.
  def blended_change_over(window)
    reference =
      if window == :launch
        launch_price
      else
        price_as_of(Date.current - window) || launch_price
      end

    blended_change_between(reference, current_price)
  end

  # Percentage change in blended price between launch and now.
  # Negative means it got cheaper.
  def blended_change_since_launch
    blended_change_over(:launch)
  end

  # Label/percentage pairs for every CHANGE_WINDOWS entry, in display order.
  # Percent is nil where there's nothing to report for that window.
  def blended_changes
    CHANGE_WINDOWS.map { |label, window| [ label, blended_change_over(window) ] }
  end

  def price_changed?
    price_points.count > 1
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

  # Shared core of the blended-change figures: % move from one snapshot's
  # blended price to another's, or nil when the move is undefined or zero
  # (missing data, a zero base, or the same snapshot on both ends).
  def blended_change_between(from_price, to_price)
    from = blended_per_mtok(from_price)
    to   = blended_per_mtok(to_price)
    return nil if from.nil? || to.nil? || from.zero? || from_price == to_price

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
end
