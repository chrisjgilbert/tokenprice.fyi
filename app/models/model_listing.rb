# The row set behind the models index table: one pricing-family tab
# (ModelCategory), filtered by provider/search/modality and sorted, plus the
# facet and tab-count data the same page renders alongside it. Extracted from
# ModelsController#index so the controller stays down to param resolution,
# conditional GET, and rendering.
#
# `sort`/`dir`/`provider_slugs`/`modalities` are taken as already resolved
# against `category` (unknown values stripped, defaults applied) — that
# validation reads request params and belongs to the controller, not here.
class ModelListing
  SORTS = {
    "input" => ->(m) { m.current_input || Float::INFINITY },
    "output" => ->(m) { m.current_output || Float::INFINITY },
    "cached" => ->(m) { m.current_cached_input || Float::INFINITY },
    "context" => ->(m) { m.context_window || 0 },
    "name" => ->(m) { m.name.to_s.downcase },
    # Image-category sorts: it has no per-token axis, so it ranks by provider and
    # release date instead. A nil release sorts oldest rather than to the top.
    "provider" => ->(m) { m.provider.name.to_s.downcase },
    "released" => ->(m) { m.released_on || Date.new(1970, 1, 1) },
    # Speech-to-text ranks on its numeric native per-minute rate; a row without
    # one maps to infinity and sinks (see SINK_SORTS).
    "native_price" => ->(m) { m.native_price_usd || Float::INFINITY }
  }.freeze

  # Price sorts a price-less row must always sink to the bottom of — regardless
  # of direction, so it never floats above a priced row when the list is
  # reversed. Each maps to the predicate that marks a row rankable on that axis:
  # a per-token rate for the token columns, a native per-minute rate for
  # speech-to-text. Name/context sort every row normally and aren't listed.
  SINK_SORTS = {
    "input" => :token_priced?, "output" => :token_priced?, "cached" => :token_priced?,
    "native_price" => :native_priced?
  }.freeze

  attr_reader :models, :modality_classes, :category_counts

  def initialize(category:, sort:, dir:, provider_slugs: [], query: "", modalities: [])
    scope = AiModel.listed.includes(:provider, :price_points)
    scope = scope.joins(:provider).where(providers: { slug: provider_slugs }) if provider_slugs.any?

    models = filter_by_query(scope.to_a, query)
    models.select! { |m| category.member?(m.modality_class) }

    # Facet options: the classes present among the rows the other filters left,
    # derived before the modality filter is applied so switching between
    # classes stays possible.
    @modality_classes = models.map { |m| m.modality_class.to_s }.uniq.sort
    models.select! { |m| modalities.include?(m.modality_class.to_s) } if modalities.any?

    @models = AiModel.sort_for_display(models, by: SORTS.fetch(sort), dir: dir, sink_unranked: SINK_SORTS[sort])
    @category_counts = compute_category_counts
  end

  private

  def filter_by_query(models, query)
    return models unless query.match?(/[a-z0-9]/i)

    if query.include?(",")
      segments = query.split(",").map(&:strip).select { |s| s.match?(/[a-z0-9]/i) }
      return models unless segments.any?

      models.select { |m| segments.any? { |seg| m.matches?(seg) } }
    else
      models.select { |m| m.matches?(query) }
    end
  end

  # Tab labels: how many listed models fall in each category, regardless of
  # this listing's own provider/search/modality filters — the badge always
  # reads the tab's full total, not the current view's filtered count.
  def compute_category_counts
    listed_classes = AiModel.listed.select(:input_modalities, :output_modalities).map(&:modality_class)
    ModelCategory.all.to_h { |category| [ category.slug, listed_classes.count { |mc| category.member?(mc) } ] }
  end
end
