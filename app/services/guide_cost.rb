# GuideCost — the per-call cost lens for the model Guide (T1.2).
#
# The Guide shows, for each pipeline step's starting options, a volume-free
# `≈ $X per call` for that step's representative token shape. This service
# computes that figure by pricing a (model slug, token shape) pair.
#
# It does NOT do money math itself: it resolves the slug through PriceCatalog,
# builds a Phase-0 CostEstimate::Profile from the shape, and delegates to
# CostEstimate#price_with(...)[:per_req]. The shape's representative token shape
# is priced once per option, so the figure is independent of monthly volume.
#
# AUDIT #1 — cache parity. Every option for a step is priced on the SAME cache
# assumption, and the launch default is NO cache discount: the profile is built
# with `cache: 0` AND `cached: nil` is passed to price_with. Two defences, so a
# future caller can't reintroduce the asymmetric-discount leak:
#   * cache: 0   — the hit rate is zero, so no cached rate can affect the figure.
#   * cached:nil — even if the hit rate were non-zero, we never hand price_with a
#                  cached rate here, so its `cache_rate = cached || input`
#                  fallback can only ever resolve to the full input rate. A model
#                  with no published cache rate can therefore never appear
#                  discounted, and a model WITH one is never silently discounted
#                  either. All options compare on one uncached basis.
#
# AUDIT #5 — unpriced steps. A FeaturePattern::Step with `priced == false` (the
# RAG embed step, a separate embeddings endpoint the catalog doesn't carry) is
# never priced: #for_step returns unpriced markers for it rather than fabricating
# a chat-completion cost.
#
# Graceful degradation. An unknown slug, a nil slug, or a model with no current
# price returns an unpriced result (per_call: nil) — the view renders "—". Never
# raises.
class GuideCost
  # One option priced for one step's shape. `per_call` is USD or nil.
  # `name` is the resolved catalog entry's display name (nil when unresolved),
  # carried so the view shows the model's name without a second lookup. `kind`
  # is the option's role (:cheap / :quality / :open_weight) so the view labels
  # it from data rather than from array position (nil for a bare #per_call).
  Result = Data.define(:slug, :name, :per_call, :resolved, :kind) do
    def resolved? = resolved
    # Priceable means: resolved to a catalog entry AND a per-call figure exists.
    def priced? = !per_call.nil?
  end

  # A frozen empty model list for CostEstimate. `price_with` is pure math that
  # never reads `@models`, so handing it an empty array avoids the redundant
  # `PriceCatalog.models` load the initializer would otherwise run.
  NO_MODELS = [].freeze

  class << self
    # Per-call cost of pricing `slug` against `shape` ({sys:, in:, out:} hash or
    # a FeaturePattern::Shape). Always on the no-cache basis (AUDIT #1).
    #
    # `catalog:` (an array of PriceCatalog::Entry) lets a caller inject the
    # already-loaded catalog so the slug resolves in-memory — a guide page loads
    # the catalog ONCE and prices every option against it. When nil, falls back
    # to PriceCatalog.model(slug) (the original per-call DB path).
    def per_call(slug:, shape:, catalog: nil)
      entry = resolve(slug, catalog)
      return Result.new(slug: slug, name: nil, per_call: nil, resolved: false, kind: nil) if entry.nil?
      return Result.new(slug: slug, name: entry.name, per_call: nil, resolved: true, kind: nil) if entry.input.nil? || entry.output.nil?

      profile = profile_for(shape)
      # cached: nil and cache: 0 — the deliberate no-discount basis (see header).
      # models: NO_MODELS — price_with never reads @models, so skip its load.
      per_req = CostEstimate.new(profile, models: NO_MODELS).price_with(
        input: entry.input, output: entry.output, cached: nil, prof: profile
      )[:per_req]

      Result.new(slug: slug, name: entry.name, per_call: per_req, resolved: true, kind: nil)
    end

    # Price every PRESENT option of a FeaturePattern::Step against the step's
    # shape, in cheap → quality → open_weight order, skipping nil option slugs.
    # Each Result carries its option `kind` so the view labels it from data, not
    # array position (a step with a nil option would otherwise shift the labels).
    # An unpriced step (priced:false, AUDIT #5) yields unpriced markers — never a
    # fabricated number.
    #
    # `catalog:` is threaded through so every option of the step resolves
    # against the SAME injected catalog (one load per page).
    def for_step(step, catalog: nil)
      shape = step.shape
      step.options.to_h.filter_map do |kind, slug|
        next if slug.nil?

        if step.priced?
          per_call(slug: slug, shape: shape, catalog: catalog).with(kind: kind)
        else
          # Resolve so the view can still name and link the model, but never price it.
          entry = resolve(slug, catalog)
          Result.new(slug: slug, name: entry&.name, per_call: nil, resolved: !entry.nil?, kind: kind)
        end
      end
    end

    private

    # Resolve a slug to a catalog Entry. With an injected `catalog` array, look
    # it up in-memory (no DB); otherwise fall back to the per-call DB path.
    def resolve(slug, catalog = nil)
      return nil if slug.nil?
      return catalog.find { |e| e.slug == slug } if catalog

      PriceCatalog.model(slug)
    end

    # Build the Phase-0 profile from the step's representative shape. req: 1 and
    # cache: 0 — per-call, volume-free, no cache discount.
    def profile_for(shape)
      h = shape.to_h
      CostEstimate.profile_from(
        sys: h[:sys], fresh: h[:in], out: h[:out], req: 1, cache: 0, tier: "any"
      )
    end
  end
end
