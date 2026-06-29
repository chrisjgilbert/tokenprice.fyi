# Public, read-only price API off the PriceCatalog seam — the citation/backlink
# flywheel and the seed of the later licensed-dataset product. Current list
# prices only; the dated history stays the paid asset.
module Api
  module V1
    class ModelsController < ApplicationController
      def index
        models = PriceCatalog.models.map do |m|
          {
            slug: m.slug,
            name: m.name,
            provider: m.provider_name,
            provider_slug: m.provider_slug,
            tier: m.tier,
            status: m.status,
            context_window: m.context_window,
            released_on: m.released_on,
            modalities: { input: m.input_modalities, output: m.output_modalities },
            modality_class: m.modality_class.to_s,
            price_per_mtok: {
              input: m.input, output: m.output, cached_input: m.cached,
              cache_write: m.cache_write, audio_input: m.audio_input
            },
            price_per_unit: {
              image_input_usd: m.image_input, request_usd: m.request
            }
          }
        end

        # Public dataset — allow cross-origin reads so it can be cited/embedded.
        response.set_header("Access-Control-Allow-Origin", "*")
        render json: {
          generated_at: Time.current.utc.iso8601,
          unit: "USD per 1,000,000 tokens",
          count: models.size,
          models: models
        }
      end
    end
  end
end
