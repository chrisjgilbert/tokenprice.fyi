class AiModel < ApplicationRecord
  # A blended $/Mtok figure assumes this input:output token mix. It gives the
  # comparison table and "cheapest model" ranking a single sortable number.
  # Roughly models a chat/agent workload that reads more than it writes.
  BLEND_INPUT_WEIGHT = 3
  BLEND_OUTPUT_WEIGHT = 1

  belongs_to :provider
  has_many :price_points, dependent: :destroy

  enum :tier, { frontier: "frontier", mid: "mid", small: "small" }, validate: true
  enum :status, { active: "active", legacy: "legacy", retired: "retired" }, validate: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :set_slug, on: :create

  scope :listed, -> { where.not(status: "retired") }
  scope :by_release, -> { order(Arel.sql("released_on IS NULL"), released_on: :desc) }

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

  # Percentage change in blended price between launch and now.
  # Negative means it got cheaper.
  def blended_change_since_launch
    from = blended_per_mtok(launch_price)
    to   = blended_per_mtok(current_price)
    return nil if from.nil? || to.nil? || from.zero? || launch_price == current_price

    (((to - from) / from) * 100).round(1)
  end

  def price_changed?
    price_points.count > 1
  end

  private

  def set_slug
    self.slug ||= name&.parameterize
  end
end
