# The education layer: a directory index plus per-concept explainers. The index
# is a clean directory only — live-data widgets live inside the explainer pages,
# never on the index, where they'd duplicate the explainer.
class LearnController < ApplicationController
  def index
  end

  # The foundational explainer: "What an AI feature is actually made of." It
  # renders worked call-chains straight off the ONE FeaturePattern source (no
  # second hardcoded copy, AUDIT #2) and carries live data (AUDIT #3): today's
  # cheapest frontier model as a worked example.
  # A curated subset of patterns teaches the idea — including the agentic LOOP
  # so the real agent pattern appears, not the coding pipeline mislabelled.
  def anatomy
    @patterns = %w[chatbot rag agentic classification].filter_map { |k| FeaturePattern.find(k) }
    # The cheapest frontier model as a worked example (PriceCatalog eager-loads,
    # so this avoids the per-model current_input N+1 of an AiModel query).
    @frontier_example = PriceCatalog.cheapest(tier: "frontier")
  end

  # The reasoning-token explainer: why thinking bills as output, why effort is a
  # volume dial rather than a price dial, and why we don't publish a per-model
  # effort multiplier (it's task-dependent, not a model constant). Carries live
  # data (AUDIT #3): the io_ratio widget — because thinking bills at the output
  # rate, the output:input spread *is* the reasoning tax — plus a worked example
  # priced off today's cheapest frontier output rate.
  def reasoning
    @catalog_last_modified = PriceCatalog.last_modified
    return if catalog_fresh?(etag: [ :learn_reasoning ], last_modified: @catalog_last_modified)

    @catalog = PriceCatalog.models
    @frontier_example = PriceCatalog.cheapest(tier: "frontier", among: @catalog)
  end

  def feature_costs
  end

  def cost_cutting
  end
end
