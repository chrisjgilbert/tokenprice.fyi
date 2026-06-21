# The education layer: a directory index plus per-concept explainers. The index
# is a clean directory only — live-data widgets live inside the explainer pages
# (and the estimator), never on the index, where they'd duplicate the explainer.
class LearnController < ApplicationController
  def index
  end

  # The foundational explainer: "What an AI feature is actually made of." It
  # renders worked call-chains straight off the ONE FeaturePattern source (no
  # second hardcoded copy, AUDIT #2) and carries live data (AUDIT #3): the
  # io_ratio widget plus today's cheapest frontier model as a worked example.
  # A curated subset of patterns teaches the idea — including the agentic LOOP
  # so the real agent pattern appears, not the coding pipeline mislabelled.
  def anatomy
    @patterns = %w[chatbot rag agentic classification].filter_map { |k| FeaturePattern.find(k) }
    # Load the catalog once and reuse it for both the io_ratio widget and the
    # frontier example, rather than the widget loading it and a second query
    # finding the cheapest frontier model (which also N+1'd on current_input).
    @catalog = PriceCatalog.models
    @frontier_example = @catalog.select { |e| e.tier == "frontier" && e.input }.min_by(&:input)
  end

  def feature_costs
  end

  def cost_cutting
  end
end
