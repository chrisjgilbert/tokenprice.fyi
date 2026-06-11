# Computes data-driven, always-current context for a model's show page: where
# its price ranks against same-tier peers, the shape of its pricing, and how it
# has moved since launch.
#
# Everything here is derived from price history at render time, so — unlike the
# hand-written editorial copy — it can never go stale when a competitor cuts
# prices or a new model ships.
class ModelInsights
  # A single bite-sized insight: a bold headline and a quieter supporting line.
  Fact = Data.define(:label, :detail)

  def initialize(model)
    @model = model
  end

  # Ordered list of the insights worth showing for this model. Each entry is
  # nil-safe — facts that can't be computed (no peers, no cached price, a single
  # snapshot) drop out rather than rendering an empty or misleading card.
  def facts
    [ rank_fact, median_fact, ratio_fact, cached_fact, trajectory_fact ].compact
  end

  # A compact one-liner for the meta description / social preview, e.g.
  # "Currently the cheapest of 9 frontier models, down 75% since launch."
  def summary_sentence
    bits = [ rank_phrase, trajectory_phrase ].compact
    return nil if bits.empty?

    "Currently #{bits.join(', ')}."
  end

  private

  attr_reader :model

  def tier_noun = "#{model.tier} model"

  # Same-tier, listed models that have a comparable blended price. The model
  # itself is included so its rank is computed against the full field.
  def cohort
    @cohort ||= AiModel.listed.where(tier: model.tier)
                       .includes(:price_points)
                       .select(&:blended_per_mtok)
  end

  # [position, field_size] with position 1 = cheapest, or [nil, size] if the
  # model has no blended price to place.
  def rank
    @rank ||= begin
      mine = model.blended_per_mtok
      sorted = cohort.sort_by(&:blended_per_mtok)
      idx = mine && sorted.index { |m| m.id == model.id }
      [ idx && idx + 1, sorted.size ]
    end
  end

  def median_blended
    values = cohort.map(&:blended_per_mtok).sort
    return nil if values.empty?

    mid = values.size / 2
    values.size.odd? ? values[mid] : (values[mid - 1] + values[mid]) / 2
  end

  def rank_phrase
    position, total = rank
    return nil unless position && total > 1

    placing = position == 1 ? "the cheapest" : "#{position.ordinalize}-cheapest"
    "#{placing} of #{total} #{tier_noun.pluralize}"
  end

  def rank_fact
    position, total = rank
    return nil unless position && total > 1

    label = position == 1 ? "Cheapest #{tier_noun}" : "#{position.ordinalize}-cheapest #{tier_noun}"
    Fact.new(label: label, detail: "by blended $/Mtok among #{total} listed #{tier_noun.pluralize}")
  end

  def median_fact
    median = median_blended
    mine = model.blended_per_mtok
    return nil if median.nil? || mine.nil? || median.zero? || cohort.size < 3

    pct = (((mine - median) / median) * 100).round
    detail = "blended $/Mtok across #{cohort.size} #{tier_noun.pluralize}"

    if pct.abs < 5
      Fact.new(label: "Right at the #{model.tier} median", detail: detail)
    else
      direction = pct.negative? ? "below" : "above"
      Fact.new(label: "#{pct.abs}% #{direction} the #{model.tier} median", detail: detail)
    end
  end

  def ratio_fact
    ratio = model.output_to_input_ratio
    return nil if ratio.nil? || ratio <= 1

    Fact.new(
      label: "Output costs #{fmt_multiple(ratio)}× input",
      detail: "#{usd_short(model.current_input)} in / #{usd_short(model.current_output)} out per 1M"
    )
  end

  def cached_fact
    discount = model.cached_input_discount
    return nil if discount.nil? || discount <= 0

    Fact.new(
      label: "Cached input saves #{(discount * 100).round}%",
      detail: "#{usd_short(model.current_cached_input)} vs #{usd_short(model.current_input)} per 1M fresh"
    )
  end

  def trajectory_phrase
    launch = model.launch_price
    return nil unless launch

    since = "since launch (#{launch.effective_on.strftime('%b %Y')})"
    change = model.blended_change_since_launch

    if change.nil? || change.zero?
      "flat #{since}"
    elsif change.negative?
      "down #{change.abs.round}% #{since}"
    else
      "up #{change.round}% #{since}"
    end
  end

  def trajectory_fact
    launch = model.launch_price
    return nil unless launch

    since = "since launch (#{launch.effective_on.strftime('%b %Y')})"
    change = model.blended_change_since_launch

    if change.nil? || change.zero?
      Fact.new(label: "Held flat #{since}", detail: "no blended price change recorded")
    elsif change.negative?
      Fact.new(label: "Down #{change.abs.round}% #{since}", detail: "blended price vs launch")
    else
      Fact.new(label: "Up #{change.round}% #{since}", detail: "blended price vs launch")
    end
  end

  # "5" not "5.0", "2.5" kept — a multiple reads cleaner without a trailing .0.
  def fmt_multiple(value)
    rounded = value.round(1)
    (rounded % 1).zero? ? rounded.to_i.to_s : rounded.to_s
  end

  def usd_short(value)
    "$#{PriceFormat.usd_amount(value)}"
  end
end
