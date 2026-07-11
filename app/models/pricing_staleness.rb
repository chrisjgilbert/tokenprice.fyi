# A freshness audit of the prices we curate by hand. The OpenRouter-synced
# language rows refresh themselves daily; everything with `source: "manual"` —
# the directory categories (image generation, speech-to-text, text-to-speech,
# video generation) and any hand-entered per-token rows — carries a figure that
# only a person updates, so it drifts as providers reprice. This groups those
# rows by category with the age of each price, flags the ones past a staleness
# threshold and the directory rows still awaiting a price, so a maintenance pass
# knows exactly what to re-verify against the docs/*_MODEL_PRICING.md datasets.
#
# A read-only reporting PORO in the ModelCategory idiom, reached via
# `PricingStaleness.report`. The `pricing:staleness` rake task formats it; keeping
# the logic here (not in the task) makes it unit-testable.
class PricingStaleness
  # One curated model's price freshness. `priced_on` is the date the price is
  # stated as-of — a directory row's `priced_as_of`, else its latest price
  # point's effective date. `status` is one of:
  #   :fresh    — priced within the threshold
  #   :stale    — priced_on is older than the threshold; re-verify
  #   :undated  — has a native price but no priced_as_of, so its age is unknown
  #   :unpriced — a directory row listed but still awaiting any price
  Row = Data.define(:slug, :name, :provider_name, :priced_on, :age_days, :status) do
    def stale?    = status == :stale
    def undated?  = status == :undated
    def unpriced? = status == :unpriced
    # Rows a maintenance pass should act on: stale, undated, or unpriced.
    def flagged?  = status != :fresh
  end

  # A category's rows plus the counts a summary line needs.
  Group = Data.define(:category, :rows) do
    def stale_count    = rows.count(&:stale?)
    def undated_count  = rows.count(&:undated?)
    def unpriced_count = rows.count(&:unpriced?)
  end

  DEFAULT_STALE_AFTER_DAYS = 90

  def self.report(...) = new(...).report

  def initialize(days: DEFAULT_STALE_AFTER_DAYS, today: Date.current)
    @days  = days
    @today = today
  end

  # Groups in ModelCategory display order, each carrying its curated rows sorted
  # oldest-price-first (unpriced rows lead). Categories with no curated rows are
  # omitted.
  def report
    curated_by_category = curated_models.group_by { |m| category_for(m) }

    ModelCategory.all.filter_map do |category|
      models = curated_by_category[category]
      next if models.blank?

      rows = models.map { |m| row_for(m) }.sort_by { |r| [ r.priced_on ? 1 : 0, r.priced_on || @today ] }
      Group.new(category:, rows:)
    end
  end

  # Flat counts across every category, for the task's closing summary.
  def totals
    rows = report.flat_map(&:rows)
    { stale: rows.count(&:stale?), undated: rows.count(&:undated?),
      unpriced: rows.count(&:unpriced?), curated: rows.size }
  end

  private

  def curated_models
    AiModel.curated.listed.includes(:provider, :price_points).to_a
  end

  def category_for(model)
    ModelCategory.all.find { |c| c.member?(model.modality_class) }
  end

  def row_for(model)
    priced_on = priced_on_for(model)
    status =
      if model.directory_listing? then :unpriced
      elsif priced_on.nil?        then :undated
      elsif priced_on < cutoff    then :stale
      else :fresh
      end

    Row.new(
      slug: model.slug,
      name: model.name,
      provider_name: model.provider.name,
      priced_on:,
      age_days: priced_on && (@today - priced_on).to_i,
      status:
    )
  end

  # The date a model's price is stated as-of: a directory row curates it
  # explicitly (`priced_as_of`); a per-token row's freshness is its latest
  # snapshot's effective date. Nil means listed-but-unpriced (a directory row
  # still awaiting a curated price).
  def priced_on_for(model)
    model.priced_as_of || model.current_price&.effective_on
  end

  def cutoff = @today - @days
end
