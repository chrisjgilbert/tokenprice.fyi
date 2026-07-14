# The row set behind the models index table: one pricing-family tab
# (ModelCategory), filtered by provider/search/modality and sorted, plus the
# facet data the same page renders alongside it. Extracted from
# ModelsController#index so the controller stays down to param resolution,
# conditional GET, and rendering. Tab badge counts are ModelCategory.counts —
# a catalog-wide total independent of any one listing's own filters, so it
# isn't part of this class.
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

  attr_reader :models, :modality_classes

  def initialize(category:, sort:, dir:, provider_slugs: [], query: "", modalities: [])
    models = matching_models(category: category, provider_slugs: provider_slugs, query: query)

    # Facet options: the classes present among the rows the other filters left,
    # so no pill leads to an empty table. Derived before the modality filter is
    # applied so switching between classes stays possible.
    @modality_classes = models.map { |m| m.modality_class.to_s }.uniq.sort
    models = models.select { |m| modalities.include?(m.modality_class.to_s) } if modalities.any?

    @models = AiModel.sort_for_display(models, by: SORTS.fetch(sort), dir: dir, sink_unranked: SINK_SORTS[sort])
  end

  private

  def matching_models(category:, provider_slugs:, query:)
    scope = AiModel.listed.includes(:provider, :price_points)
    # A hash-keyed `.where(providers: {...})` combined with `.joins(:provider)`
    # trips Rails' auto-reference detection and switches the whole scope from
    # preload to eager_load — one LEFT OUTER JOIN against price_points that
    # fans a row out per price point instead of per model. A `where(provider:
    # <relation>)` subquery filters by provider_id without triggering that.
    scope = scope.where(provider: Provider.where(slug: provider_slugs)) if provider_slugs.any?
    filter_by_query(scope.to_a, query).select { |m| category.member?(m.modality_class) }
  end

  def filter_by_query(models, query)
    segments = query.split(",").map(&:strip).select { |s| s.match?(/[a-z0-9]/i) }
    return models if segments.empty?

    models.select { |m| segments.any? { |seg| m.matches?(seg) } }
  end
end
