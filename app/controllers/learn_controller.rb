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
  # priced off a recognizable premium model's output rate.
  def reasoning
    @catalog_last_modified = PriceCatalog.last_modified
    return if catalog_fresh?(etag: [ :learn_reasoning ], last_modified: @catalog_last_modified)

    @catalog = PriceCatalog.models
    @premium_example = PriceCatalog.baseline(among: @catalog)
  end

  def feature_costs
    @catalog_last_modified = PriceCatalog.last_modified
    return if catalog_fresh?(etag: [ :learn_feature_costs ], last_modified: @catalog_last_modified)

    @catalog = PriceCatalog.models
    @picker_models = @catalog.select { |m| m.input && m.output }
                             .sort_by { |m| [ m.provider_name, m.name ] }
    @default_picker = PriceCatalog.baseline(among: @picker_models) || @picker_models.first
    @small_ref_input = @picker_models.filter_map(&:input).min || 0.1
  end

  def cost_cutting
  end
end
