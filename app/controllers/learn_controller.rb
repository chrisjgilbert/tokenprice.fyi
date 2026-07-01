# The education layer: a directory index plus per-concept explainers. The index
# is a clean directory only — live-data widgets live inside the explainer pages,
# never on the index, where they'd duplicate the explainer.
class LearnController < ApplicationController
  def index
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
    @catalog_last_modified = PriceCatalog.last_modified
    return if catalog_fresh?(etag: [ :learn_feature_costs ], last_modified: @catalog_last_modified)

    @catalog = PriceCatalog.models
    @picker_models = @catalog.select { |m| m.input && m.output }
                             .sort_by { |m| [ m.provider_name, m.name ] }
    @default_picker = PriceCatalog.cheapest(tier: "mid", among: @picker_models) || @picker_models.first
    @small_ref_input = PriceCatalog.cheapest(tier: "small", among: @catalog)&.input || 0.1
  end

  def cost_cutting
  end

  # The modality explainer: how images and audio land on the token meter, why the
  # count comes from a picture's resolution or a clip's length rather than its
  # meaning, and why non-text input and output often bill at their own rates.
  # Static — the worked examples state their own assumptions rather than pricing
  # off the catalog, because per-modality rates aren't modelled in PriceCatalog.
  def modality
  end
end
