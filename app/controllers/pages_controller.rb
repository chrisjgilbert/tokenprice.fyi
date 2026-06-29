class PagesController < ApplicationController
  def llms_txt
    @providers = Provider.all.order(:name)
    @patterns  = FeaturePattern.all
    render formats: :txt
  end

  def how_pricing_works
    # The catalog freshness timestamp drives the conditional-GET key below, so
    # the page issues a single freshness query.
    @catalog_last_modified = PriceCatalog.last_modified
    return if catalog_fresh?(etag: [ :how_pricing_works ], last_modified: @catalog_last_modified)

    # The cheapest frontier model as a worked example (PriceCatalog eager-loads,
    # so this avoids the per-model current_input N+1 of an AiModel query).
    @frontier_example = PriceCatalog.cheapest(tier: "frontier")
  end
end
