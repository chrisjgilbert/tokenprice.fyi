class PagesController < ApplicationController
  def how_pricing_works
    # The cheapest frontier model as a worked example (PriceCatalog eager-loads,
    # so this avoids the per-model current_input N+1 of an AiModel query).
    @frontier_example = PriceCatalog.cheapest(tier: "frontier")
  end
end
