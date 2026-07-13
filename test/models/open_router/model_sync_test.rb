require "test_helper"

module OpenRouter
  class ModelSyncTest < ActiveSupport::TestCase
    # A stub standing in for OpenRouter::Client — returns a fixed catalogue.
    FakeClient = Struct.new(:rows) { def models = rows }

    # Build an OpenRouter-shaped model hash. Prices are USD *per token* strings,
    # exactly as the real API returns them.
    def or_model(id:, name:, prompt:, completion:, cache_read: "0",
                 cache_write: nil, image: nil, audio: nil, video: nil, request: nil,
                 context: 200_000, max_out: 8_192, created: 1_700_000_000,
                 input_modalities: [ "text" ], output_modalities: [ "text" ],
                 description: "An OpenRouter model.")
      pricing = { "prompt" => prompt, "completion" => completion,
                  "input_cache_read" => cache_read }
      pricing["input_cache_write"] = cache_write unless cache_write.nil?
      pricing["image"]   = image   unless image.nil?
      pricing["audio"]   = audio   unless audio.nil?
      pricing["video"]   = video   unless video.nil?
      pricing["request"] = request unless request.nil?

      {
        "id" => id, "name" => name, "created" => created,
        "description" => description, "context_length" => context,
        "architecture" => { "input_modalities" => input_modalities,
                            "output_modalities" => output_modalities },
        "pricing" => pricing,
        "top_provider" => { "context_length" => context, "max_completion_tokens" => max_out }
      }
    end

    # `describer: nil` keeps generation off for the bulk of the suite (it would
    # otherwise reach for the Anthropic API on every created row); the
    # description-generation tests pass an explicit fake describer.
    def sync(rows, today: Date.current, describer: nil)
      ModelSync.new(client: FakeClient.new(rows), today: today,
                    describer: describer, logger: ActiveSupport::Logger.new(nil)).call
    end

    test "creates new models, skips curated duplicates and genuinely free rows" do
      rows = [
        # Duplicates curated `opus` (Claude Opus 4.8) -> skipped, left untouched.
        or_model(id: "anthropic/claude-opus-4.8", name: "Anthropic: Claude Opus 4.8",
                 prompt: "0.000005", completion: "0.000025"),
        # New model under the existing Anthropic provider.
        or_model(id: "anthropic/claude-haiku-4.5", name: "Anthropic: Claude Haiku 4.5",
                 prompt: "0.000001", completion: "0.000005"),
        # New provider + model.
        or_model(id: "newlab/wonder-1", name: "NewLab: Wonder 1",
                 prompt: "0.0000001", completion: "0.0000004"),
        # Free model -> skipped.
        or_model(id: "freeco/free-1", name: "FreeCo: Free 1",
                 prompt: "0", completion: "0")
      ]

      result = assert_difference("AiModel.count", 2) { sync(rows) }

      assert_equal 2, result.created
      assert_equal 2, result.skipped

      # Curated Opus is untouched: no parallel record, original data intact.
      assert_equal 1, AiModel.where("name = ?", "Claude Opus 4.8").count
      opus = ai_models(:opus).reload
      assert_equal AiModel::MANUAL_SOURCE, opus.source
      assert_equal "Test model.", opus.description
      assert_equal 1, opus.price_points.count

      # Free row created neither a provider nor a model.
      assert_nil Provider.find_by(slug: "freeco")
    end

    test "a price-less directory row is left out of the Slack digest" do
      rows = [ or_model(id: "blackforest/flux-1", name: "Black Forest Labs: FLUX.1",
                        prompt: "0", completion: "0", output_modalities: [ "image" ]) ]

      result = sync(rows)
      assert_equal 1, result.created
      assert_empty result.created_records
    end

    test "an image+text output model keeps its per-token price and classes as image generation" do
      # Gemini's image model ("nano banana") emits image and text and is priced
      # per token; it lands in image_generation, not the omni catch-all, and
      # keeps its price rather than being treated as a price-less directory row.
      rows = [ or_model(id: "google/gemini-image", name: "Google: Gemini Image",
                        prompt: "0.0000003", completion: "0.0000025",
                        output_modalities: [ "image", "text" ]) ]
      sync(rows)

      model = AiModel.find_by!(openrouter_id: "google/gemini-image")
      assert_equal :image_generation, model.modality_class
      assert model.priced?
      assert_in_delta 0.3, model.current_input, 0.0001
      assert_not model.directory_listing?
    end

    test "a created model is mapped onto our schema" do
      sync([ or_model(id: "anthropic/claude-haiku-4.5", name: "Anthropic: Claude Haiku 4.5",
                      prompt: "0.000001", completion: "0.000005", context: 200_000,
                      max_out: 64_000, created: Time.utc(2025, 10, 15).to_i) ])

      model = AiModel.find_by!(openrouter_id: "anthropic/claude-haiku-4.5")
      assert_equal providers(:anthropic), model.provider
      assert_equal "Claude Haiku 4.5", model.name
      assert_equal "anthropic-claude-haiku-4-5", model.slug
      assert_equal AiModel::OPENROUTER_SOURCE, model.source
      assert_equal 200_000, model.context_window
      assert_equal 64_000, model.max_output_tokens
      assert_equal Date.new(2025, 10, 15), model.released_on
      assert_equal "mid", model.tier

      price = model.current_price
      assert_equal 1.0, price.input_per_mtok
      assert_equal 5.0, price.output_per_mtok
      assert_nil price.cached_input_per_mtok # "0" cache read normalised to nil
      assert_equal "openrouter.ai", price.source
    end

    test "creates and names an unknown provider from the catalogue" do
      assert_difference("Provider.count", 1) do
        sync([ or_model(id: "newlab/wonder-1", name: "NewLab: Wonder 1",
                        prompt: "0.0000001", completion: "0.0000004") ])
      end

      provider = Provider.find_by!(slug: "newlab")
      assert_equal "NewLab", provider.name
      # Imported models land in a neutral tier for a human to re-curate.
      assert_equal "mid", provider.ai_models.first.tier
    end

    test "names a new provider from the namespace when the row has no colon prefix" do
      sync([ or_model(id: "nous/hermes-4", name: "Hermes 4",
                      prompt: "0.0000004", completion: "0.0000004") ])

      provider = Provider.find_by!(slug: "nous")
      assert_equal "Nous", provider.name # not "Hermes 4"
      assert_equal "Hermes 4", provider.ai_models.first.name
    end

    test "an unchanged price with a 0/nil cached mismatch does not churn" do
      model = ai_models(:deepseek_v4)
      model.update!(openrouter_id: "deepseek/deepseek-v4-pro")
      # A curated point storing literal 0 for the cached tier.
      model.price_points.create!(effective_on: Date.current, input_per_mtok: 1,
                                 output_per_mtok: 2, cached_input_per_mtok: 0)

      # Same input/output, no cached tier in the API payload (-> nil).
      assert_no_difference "PricePoint.count" do
        result = sync([ or_model(id: "deepseek/deepseek-v4-pro", name: "DeepSeek: V4 Pro",
                                 prompt: "0.000001", completion: "0.000002", cache_read: "0") ],
                      today: Date.current + 1)
        assert_equal 0, result.repriced
      end
    end

    test "is idempotent: re-running writes no new models or price points" do
      rows = [ or_model(id: "anthropic/claude-haiku-4.5", name: "Anthropic: Claude Haiku 4.5",
                        prompt: "0.000001", completion: "0.000005") ]
      sync(rows)

      assert_no_difference [ "AiModel.count", "PricePoint.count" ] do
        result = sync(rows, today: Date.current + 1)
        assert_equal 0, result.created
        assert_equal 0, result.repriced
        assert_equal 1, result.enriched
      end
    end

    test "appends a dated price point only when the price moves" do
      id = "anthropic/claude-haiku-4.5"
      sync([ or_model(id: id, name: "Anthropic: Claude Haiku 4.5",
                      prompt: "0.000001", completion: "0.000005") ])
      model = AiModel.find_by!(openrouter_id: id)
      assert_equal 1, model.price_points.count

      # Price moves the next day -> a new snapshot is appended.
      result = sync([ or_model(id: id, name: "Anthropic: Claude Haiku 4.5",
                               prompt: "0.0000008", completion: "0.000005") ],
                     today: Date.current + 1)
      assert_equal 1, result.repriced
      assert_equal 2, model.reload.price_points.count
      assert_equal 0.8, model.current_price.input_per_mtok
      assert_equal Date.current + 1, model.current_price.effective_on
    end

    test "enriches an admin-linked curated model without overwriting its data" do
      deepseek = ai_models(:deepseek_v4)
      deepseek.update!(openrouter_id: "deepseek/deepseek-v4-pro", description: "Curated copy.")
      before = deepseek.price_points.count

      sync([ or_model(id: "deepseek/deepseek-v4-pro", name: "DeepSeek: V4 Pro",
                      prompt: "0.0000009", completion: "0.0000018") ],
           today: Date.current)

      deepseek.reload
      # Stays curated, keeps its hand-written description and tier.
      assert_equal AiModel::MANUAL_SOURCE, deepseek.source
      assert_equal "Curated copy.", deepseek.description
      assert_equal "frontier", deepseek.tier
      # But its price history is enriched from OpenRouter.
      assert_equal before + 1, deepseek.price_points.count
      assert_equal "openrouter.ai", deepseek.current_price.source
    end

    test "retires previously-imported 'Latest' alias models" do
      trailing = AiModel.create!(
        name: "Claude Opus Latest", slug: "claude-opus-latest",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "anthropic/claude-opus:latest",
        status: "active", tier: "mid"
      )
      parenthesized = AiModel.create!(
        name: "GPT-4o (Latest)", slug: "gpt-4o-latest",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "openai/gpt-4o:latest",
        status: "active", tier: "mid"
      )

      id_only = AiModel.create!(
        name: "Claude Opus 4.8", slug: "claude-opus-48-latest",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "anthropic/claude-opus-4.8:latest",
        status: "active", tier: "mid"
      )

      sync([])

      assert_equal "retired", trailing.reload.status
      assert_equal "retired", parenthesized.reload.status
      assert_equal "retired", id_only.reload.status
    end

    test "skips 'Latest' alias models that duplicate versioned entries" do
      rows = [
        or_model(id: "anthropic/claude-opus-4.8:latest", name: "Anthropic: Claude Opus Latest",
                 prompt: "0.000005", completion: "0.000025"),
        or_model(id: "openai/gpt-4o:latest", name: "OpenAI: GPT-4o Latest",
                 prompt: "0.0000025", completion: "0.00001"),
        or_model(id: "newlab/wonder-1", name: "NewLab: Wonder 1",
                 prompt: "0.0000001", completion: "0.0000004")
      ]

      result = assert_difference("AiModel.count", 1) { sync(rows) }

      assert_equal 1, result.created
      assert_equal 2, result.skipped
      assert_nil AiModel.find_by(openrouter_id: "anthropic/claude-opus-4.8:latest")
      assert_nil AiModel.find_by(openrouter_id: "openai/gpt-4o:latest")
      assert AiModel.find_by(openrouter_id: "newlab/wonder-1")
    end

    test "skips ':latest' alias even when the display name omits 'latest'" do
      rows = [
        or_model(id: "anthropic/claude-opus:latest", name: "Anthropic: Claude Opus 4.8",
                 prompt: "0.000005", completion: "0.000025")
      ]

      result = assert_difference("AiModel.count", 0) { sync(rows) }
      assert_equal 1, result.skipped
    end

    test "retires previously-imported ':fast' speed variant models" do
      fast_opus = AiModel.create!(
        name: "Claude Opus 4.6 (Fast)", slug: "claude-opus-4-6-fast",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "anthropic/claude-opus-4.6:fast",
        status: "active", tier: "mid"
      )
      fast_sonnet = AiModel.create!(
        name: "Claude Sonnet 4.6 (Fast)", slug: "claude-sonnet-4-6-fast",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "anthropic/claude-sonnet-4.6:fast",
        status: "active", tier: "mid"
      )
      # Marker only in the name; id stays plain (no ":fast" suffix).
      named_fast = AiModel.create!(
        name: "Claude Opus 4.7 (Fast)", slug: "claude-opus-4-7-fast",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "anthropic/claude-opus-4.7-fast",
        status: "active", tier: "mid"
      )

      sync([])

      assert_equal "retired", fast_opus.reload.status
      assert_equal "retired", fast_sonnet.reload.status
      assert_equal "retired", named_fast.reload.status
    end

    test "leaves genuinely distinct models with 'Fast' in the name alone" do
      grok = AiModel.create!(
        name: "Grok 4.1 Fast", slug: "grok-4-1-fast",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "x-ai/grok-4.1-fast",
        status: "active", tier: "small"
      )

      sync([])

      assert_equal "active", grok.reload.status
    end

    test "skips ':fast' speed variant models during import" do
      rows = [
        or_model(id: "anthropic/claude-opus-4.8:fast", name: "Anthropic: Claude Opus 4.8 (Fast)",
                 prompt: "0.00001", completion: "0.00005"),
        or_model(id: "anthropic/claude-opus-4.7:fast", name: "Anthropic: Claude Opus 4.7 (Fast)",
                 prompt: "0.00003", completion: "0.00015"),
        # Marker only in the name; id has no ":fast" suffix.
        or_model(id: "anthropic/claude-opus-4.6", name: "Anthropic: Claude Opus 4.6 (Fast)",
                 prompt: "0.00003", completion: "0.00015"),
        or_model(id: "newlab/wonder-1", name: "NewLab: Wonder 1",
                 prompt: "0.0000001", completion: "0.0000004")
      ]

      result = assert_difference("AiModel.count", 1) { sync(rows) }

      assert_equal 1, result.created
      assert_equal 3, result.skipped
      assert_nil AiModel.find_by(openrouter_id: "anthropic/claude-opus-4.8:fast")
      assert_nil AiModel.find_by(openrouter_id: "anthropic/claude-opus-4.7:fast")
      assert_nil AiModel.find_by(openrouter_id: "anthropic/claude-opus-4.6")
      assert AiModel.find_by(openrouter_id: "newlab/wonder-1")
    end

    test "retires previously-imported same-priced suffixed twins, keeping the canonical row" do
      base = AiModel.create!(
        name: "GPT-5.6 Sol", slug: "gpt-5-6-sol",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "openai/gpt-5.6-sol", status: "active", tier: "frontier"
      )
      base.price_points.create!(effective_on: Date.new(2026, 7, 9), input_per_mtok: 5, output_per_mtok: 30)

      twin = AiModel.create!(
        name: "GPT-5.6 Sol Pro", slug: "gpt-5-6-sol-pro",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "openai/gpt-5.6-sol-pro", status: "active", tier: "mid"
      )
      twin.price_points.create!(effective_on: Date.new(2026, 7, 9), input_per_mtok: 5, output_per_mtok: 30)

      sync([])

      assert_equal "active",  base.reload.status
      assert_equal "retired", twin.reload.status
    end

    test "leaves a suffixed variant priced above its base alone" do
      base = AiModel.create!(
        name: "GPT-5.5", slug: "gpt-5-5-or",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "openai/gpt-5.5", status: "active", tier: "frontier"
      )
      base.price_points.create!(effective_on: Date.new(2026, 6, 1), input_per_mtok: 5, output_per_mtok: 30)

      premium = AiModel.create!(
        name: "GPT-5.5 Pro", slug: "gpt-5-5-pro-or",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "openai/gpt-5.5-pro", status: "active", tier: "frontier"
      )
      premium.price_points.create!(effective_on: Date.new(2026, 6, 1), input_per_mtok: 30, output_per_mtok: 180)

      sync([])

      assert_equal "active", premium.reload.status
    end

    test "skips a same-priced suffixed twin during import but keeps a pricier one" do
      rows = [
        or_model(id: "openai/gpt-5.6-sol", name: "OpenAI: GPT-5.6 Sol",
                 prompt: "0.000005", completion: "0.00003"),
        # Same price as Sol, name extends it -> alias twin, skipped.
        or_model(id: "openai/gpt-5.6-sol-pro", name: "OpenAI: GPT-5.6 Sol Pro",
                 prompt: "0.000005", completion: "0.00003"),
        # Extends Sol's name but charges a premium -> genuine variant, kept.
        or_model(id: "openai/gpt-5.6-sol-max", name: "OpenAI: GPT-5.6 Sol Max",
                 prompt: "0.00003", completion: "0.00018")
      ]

      assert_difference("AiModel.count", 2) { sync(rows) }

      assert AiModel.find_by(openrouter_id: "openai/gpt-5.6-sol")
      assert_nil AiModel.find_by(openrouter_id: "openai/gpt-5.6-sol-pro")
      assert AiModel.find_by(openrouter_id: "openai/gpt-5.6-sol-max")
    end

    test "keeps a same-priced dated snapshot rather than retiring it as a twin" do
      base = AiModel.create!(
        name: "Nova 2", slug: "nova-2",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "acme/nova-2", status: "active", tier: "frontier"
      )
      base.price_points.create!(effective_on: Date.new(2026, 7, 1), input_per_mtok: 2, output_per_mtok: 8)

      snapshot = AiModel.create!(
        name: "Nova 2 20260715", slug: "nova-2-20260715",
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        openrouter_id: "acme/nova-2-20260715", status: "active", tier: "frontier"
      )
      snapshot.price_points.create!(effective_on: Date.new(2026, 7, 1), input_per_mtok: 2, output_per_mtok: 8)

      sync([])

      assert_equal "active", base.reload.status
      assert_equal "active", snapshot.reload.status
    end

    test "one malformed row does not abort the whole sync" do
      rows = [
        { "id" => "broken/row" }, # no pricing -> skipped, not fatal
        or_model(id: "newlab/wonder-1", name: "NewLab: Wonder 1",
                 prompt: "0.0000001", completion: "0.0000004")
      ]

      result = nil
      assert_difference("AiModel.count", 1) { result = sync(rows) }
      assert_equal 1, result.created
      assert_equal 1, result.skipped
    end

    # --- created_records / repriced_records population ----------------------

    test "created model populates created_records with model and provider info" do
      result = sync([ or_model(id: "anthropic/claude-haiku-4.5", name: "Anthropic: Claude Haiku 4.5",
                               prompt: "0.000001", completion: "0.000005") ])

      assert_equal 1, result.created_records.size
      rec = result.created_records.first
      assert_equal "Claude Haiku 4.5",  rec.model_name
      assert_equal "Anthropic",         rec.provider_name
      assert_equal "anthropic-claude-haiku-4-5", rec.model_slug
      assert_equal 1.0,                 rec.input_per_mtok
      assert_equal 5.0,                 rec.output_per_mtok
      assert_equal false,               rec.new_provider
    end

    test "new_provider is true when the provider did not exist before" do
      result = sync([ or_model(id: "brandnew/model-1", name: "BrandNew: Model 1",
                               prompt: "0.000001", completion: "0.000004") ])

      assert_equal 1, result.created_records.size
      assert_equal true, result.created_records.first.new_provider
    end

    test "new_provider is false when provider already existed" do
      # anthropic provider exists in fixtures
      result = sync([ or_model(id: "anthropic/claude-haiku-4.5", name: "Anthropic: Claude Haiku 4.5",
                               prompt: "0.000001", completion: "0.000005") ])

      assert_equal false, result.created_records.first.new_provider
    end

    test "first-price models (created) do not populate repriced_records" do
      result = sync([ or_model(id: "anthropic/claude-haiku-4.5", name: "Anthropic: Claude Haiku 4.5",
                               prompt: "0.000001", completion: "0.000005") ])

      assert_equal 0, result.repriced_records.size
    end

    test "repriced model populates repriced_records with correct old/new pricing" do
      id = "anthropic/claude-haiku-4.5"
      # First sync — creates the model and records first price.
      sync([ or_model(id: id, name: "Anthropic: Claude Haiku 4.5",
                      prompt: "0.000001", completion: "0.000005") ])

      # Second sync with a new price.
      result = sync([ or_model(id: id, name: "Anthropic: Claude Haiku 4.5",
                               prompt: "0.0000008", completion: "0.000005") ],
                    today: Date.current + 1)

      assert_equal 1, result.repriced_records.size
      rec = result.repriced_records.first
      assert_equal "Claude Haiku 4.5", rec.model_name
      assert_equal "Anthropic",        rec.provider_name
      assert_equal 1.0,                rec.old_input
      assert_equal 5.0,                rec.old_output
      assert_equal 0.8,                rec.new_input
      assert_equal 5.0,                rec.new_output
    end

    test "pct_input_change is calculated correctly for a price drop" do
      id = "anthropic/claude-haiku-4.5"
      # old: input=1
      sync([ or_model(id: id, name: "Anthropic: Claude Haiku 4.5",
                      prompt: "0.000001", completion: "0.000005") ])
      # new: input=0.5 => pct = (0.5 - 1) / 1 * 100 = -50.0
      result = sync([ or_model(id: id, name: "Anthropic: Claude Haiku 4.5",
                               prompt: "0.0000005", completion: "0.000005") ],
                    today: Date.current + 1)

      rec = result.repriced_records.first
      assert_in_delta(-50.0, rec.pct_input_change, 0.05)
    end

    test "unchanged price does not populate repriced_records" do
      id = "anthropic/claude-haiku-4.5"
      rows = [ or_model(id: id, name: "Anthropic: Claude Haiku 4.5",
                        prompt: "0.000001", completion: "0.000005") ]
      sync(rows)

      result = sync(rows, today: Date.current + 1)
      assert_equal 0, result.repriced_records.size
      assert_equal 0, result.created_records.size
    end

    # --- modality signature -------------------------------------------------

    test "an owned row stores its normalised modality signature" do
      sync([ or_model(id: "newlab/vision-1", name: "NewLab: Vision 1",
                      prompt: "0.000001", completion: "0.000005",
                      input_modalities: [ "Text", "IMAGE" ], output_modalities: [ "text" ]) ])

      model = AiModel.find_by!(openrouter_id: "newlab/vision-1")
      assert_equal %w[image text], model.input_modalities.sort
      assert_equal %w[text], model.output_modalities
      assert model.multimodal?
      assert_equal :multimodal, model.modality_class
    end

    test "an owned row's signature drops tokens outside the closed vocabulary" do
      sync([ or_model(id: "newlab/odd-1", name: "NewLab: Odd 1",
                      prompt: "0.000001", completion: "0.000005",
                      input_modalities: [ "text", "hologram" ], output_modalities: [ "text" ]) ])

      model = AiModel.find_by!(openrouter_id: "newlab/odd-1")
      assert_equal %w[text], model.input_modalities
      refute model.multimodal?
    end

    test "a re-synced owned row keeps its signature fresh (overwrite)" do
      id = "newlab/vision-1"
      sync([ or_model(id: id, name: "NewLab: Vision 1",
                      prompt: "0.000001", completion: "0.000005",
                      input_modalities: [ "text" ]) ])
      model = AiModel.find_by!(openrouter_id: id)
      refute model.multimodal?

      sync([ or_model(id: id, name: "NewLab: Vision 1",
                      prompt: "0.000001", completion: "0.000005",
                      input_modalities: [ "text", "image" ]) ],
           today: Date.current + 1)

      assert_equal %w[image text], model.reload.input_modalities.sort
      assert model.multimodal?
    end

    test "a re-synced owned row keeps a recorded signature when the payload omits architecture" do
      id = "newlab/vision-2"
      sync([ or_model(id: id, name: "NewLab: Vision 2",
                      prompt: "0.000001", completion: "0.000005",
                      input_modalities: [ "text", "image" ]) ])
      model = AiModel.find_by!(openrouter_id: id)
      assert model.multimodal?

      # A later payload that drops `architecture` must not wipe the signature to [].
      bare = { "id" => id, "name" => "NewLab: Vision 2", "created" => 1_700_000_000,
               "description" => "Same model, bare payload.", "context_length" => 100_000,
               "pricing" => { "prompt" => "0.000001", "completion" => "0.000005" },
               "top_provider" => { "context_length" => 100_000, "max_completion_tokens" => 8_192 } }
      sync([ bare ], today: Date.current + 1)

      assert_equal %w[image text], model.reload.input_modalities.sort
      assert model.multimodal?
    end

    test "a curated/linked row's signature is filled only when blank, never overwritten" do
      deepseek = ai_models(:deepseek_v4)
      deepseek.update!(openrouter_id: "deepseek/deepseek-v4-pro",
                       input_modalities: [ "text", "audio" ], output_modalities: [ "text" ])

      sync([ or_model(id: "deepseek/deepseek-v4-pro", name: "DeepSeek: V4 Pro",
                      prompt: "0.0000009", completion: "0.0000018",
                      input_modalities: [ "text", "image" ]) ])

      deepseek.reload
      # Curated signature is preserved, not stomped by the OpenRouter payload.
      assert_equal %w[audio text], deepseek.input_modalities.sort
    end

    test "a curated/linked row with a blank signature is filled from the payload" do
      deepseek = ai_models(:deepseek_v4)
      deepseek.update!(openrouter_id: "deepseek/deepseek-v4-pro",
                       input_modalities: [], output_modalities: [])

      sync([ or_model(id: "deepseek/deepseek-v4-pro", name: "DeepSeek: V4 Pro",
                      prompt: "0.0000009", completion: "0.0000018",
                      input_modalities: [ "text", "image" ], output_modalities: [ "text" ]) ])

      deepseek.reload
      assert_equal %w[image text], deepseek.input_modalities.sort
      assert_equal %w[text], deepseek.output_modalities
    end

    test "a row with no architecture stores empty modality arrays and does not raise" do
      row = {
        "id" => "newlab/bare-1", "name" => "NewLab: Bare 1", "created" => 1_700_000_000,
        "description" => "A bare row.", "context_length" => 100_000,
        "pricing" => { "prompt" => "0.000001", "completion" => "0.000005",
                       "input_cache_read" => "0" },
        "top_provider" => { "context_length" => 100_000, "max_completion_tokens" => 8_192 }
      }

      assert_nothing_raised { sync([ row ]) }

      model = AiModel.find_by!(openrouter_id: "newlab/bare-1")
      assert_equal [], model.input_modalities
      assert_equal [], model.output_modalities
      assert_equal :text, model.modality_class
    end

    # --- directory classes are admitted; other non-text outputs are skipped ---

    test "an image-generation row is admitted as a price-less directory listing" do
      result = assert_difference("AiModel.count", 1) do
        sync([ or_model(id: "google/imagen-4", name: "Google: Imagen 4",
                        prompt: "0", completion: "0", image: "0.04",
                        input_modalities: [ "text" ], output_modalities: [ "image" ]) ])
      end

      assert_equal 1, result.created
      model = AiModel.find_by!(openrouter_id: "google/imagen-4")
      assert_equal :image_generation, model.modality_class
      assert_empty model.price_points
      assert model.directory_listing?
      assert_includes AiModel.listed, model
    end

    test "an embedding row is admitted and priced input-only" do
      # Embeddings carry a real prompt price with completion "0" (meaningless for a
      # vector output). The row is admitted and priced on INPUT only: the price
      # point stores the input rate with a nil — not $0 — output.
      result = assert_difference("AiModel.count", 1) do
        sync([ or_model(id: "openai/text-embedding-3-small", name: "OpenAI: Text Embedding 3 Small",
                        prompt: "0.00000002", completion: "0",
                        input_modalities: [ "text" ], output_modalities: [ "embedding" ]) ])
      end

      assert_equal 1, result.created
      model = AiModel.find_by!(openrouter_id: "openai/text-embedding-3-small")
      assert_equal :embedding, model.modality_class
      assert model.token_priced?
      assert_includes AiModel.listed, model

      price = model.current_price
      assert_equal 0.02, price.input_per_mtok
      assert_nil price.output_per_mtok # nil, not a misleading $0
    end

    test "an embedding-output row whose input is omitted is skipped, not priced with a $0 output" do
      # Without an input modality the row classifies as :other (not :embedding), so
      # embedding? is false. Admission keys on embedding? — not the raw output
      # signature — so the row stays out rather than storing a misleading $0 output
      # and posting a "$0" digest line on a model that wouldn't even list here.
      result = assert_no_difference("AiModel.count") do
        sync([ or_model(id: "someco/mystery-embed", name: "SomeCo: Mystery Embed",
                        prompt: "0.00000002", completion: "0",
                        input_modalities: [], output_modalities: [ "embedding" ]) ])
      end

      assert_equal 1, result.skipped
      assert_empty result.created_records
      assert_nil AiModel.find_by(openrouter_id: "someco/mystery-embed")
    end

    test "re-syncing an embedding row does not churn a duplicate snapshot" do
      row = or_model(id: "openai/text-embedding-3-small", name: "OpenAI: Text Embedding 3 Small",
                     prompt: "0.00000002", completion: "0",
                     output_modalities: [ "embedding" ])
      sync([ row ])
      model = AiModel.find_by!(openrouter_id: "openai/text-embedding-3-small")
      assert_equal 1, model.price_points.count

      # The completion "0" must not read as a price change against the stored nil
      # output — an embedding is reprice-stable across runs.
      assert_no_difference "PricePoint.count" do
        result = sync([ row ], today: Date.current + 1)
        assert_equal 0, result.repriced
      end
    end

    test "an embedding row is left out of the Slack digest (no $0 output line)" do
      # The digest formats an input/output pair; an embedding has no output rate,
      # so — like a price-less directory row — it's kept out rather than posting $0.
      result = sync([ or_model(id: "openai/text-embedding-3-small", name: "OpenAI: Text Embedding 3 Small",
                               prompt: "0.00000002", completion: "0",
                               output_modalities: [ "embedding" ]) ])

      assert_equal 1, result.created
      assert_empty result.created_records
    end

    test "a text model still records a price point (regression)" do
      sync([ or_model(id: "anthropic/claude-haiku-4.5", name: "Anthropic: Claude Haiku 4.5",
                      prompt: "0.000001", completion: "0.000005") ])

      model = AiModel.find_by!(openrouter_id: "anthropic/claude-haiku-4.5")
      assert_equal 1, model.price_points.count
      assert_equal 1.0, model.current_price.input_per_mtok
    end

    test "a text-to-speech row is admitted as a price-less directory listing" do
      # Text-only in, audio out is synthesis — a directory class now — so a
      # price-less TTS row is admitted and listed as "not yet tracked", like image.
      result = sync([ or_model(id: "someco/tts-1", name: "SomeCo: TTS 1",
                               prompt: "0", completion: "0",
                               input_modalities: [ "text" ], output_modalities: [ "audio" ]) ])

      assert_equal 1, result.created
      model = AiModel.find_by!(openrouter_id: "someco/tts-1")
      assert_equal :text_to_speech, model.modality_class
      assert model.directory_listing?
    end

    test "a non-directory media row with no price is still skipped" do
      # A multi-output non-text signature (text + audio) is omnimodal, not a
      # directory class, so with no usable price it's skipped rather than admitted.
      result = assert_no_difference("AiModel.count") do
        sync([ or_model(id: "someco/omni-1", name: "SomeCo: Omni 1",
                        prompt: "0", completion: "0",
                        input_modalities: [ "text" ], output_modalities: [ "text", "audio" ]) ])
      end

      assert_equal 1, result.skipped
      assert_nil AiModel.find_by(openrouter_id: "someco/omni-1")
    end

    test "a text-output row with only a partial token price is skipped, not mislabelled" do
      # prompt blank → parse_pricing returns nil; a half-entered token price has no
      # storable per-token rate, so the row is skipped rather than written as $0.
      result = assert_no_difference("AiModel.count") do
        sync([ or_model(id: "halfco/half-1", name: "HalfCo: Half 1",
                        prompt: "", completion: "0.000005",
                        output_modalities: [ "text" ]) ])
      end

      assert_equal 1, result.skipped
      assert_nil AiModel.find_by(openrouter_id: "halfco/half-1")
    end

    # --- extra price dimensions (cache-write / audio / image / request) -----

    test "a text row stores the four extra price dimensions in the right units" do
      sync([ or_model(id: "anthropic/claude-haiku-4.5", name: "Anthropic: Claude Haiku 4.5",
                      prompt: "0.000001", completion: "0.000005",
                      cache_write: "0.00000125", audio: "0.0001",
                      image: "0.04", request: "0.005") ])

      price = AiModel.find_by!(openrouter_id: "anthropic/claude-haiku-4.5").current_price
      # per-token dimensions are scaled to per-1M-tokens.
      assert_equal 1.25, price.cache_write_per_mtok
      assert_equal 100.0, price.audio_input_per_mtok
      # per-image / per-request dimensions are raw USD (no ×1M).
      assert_equal 0.04, price.image_input_usd
      assert_equal 0.005, price.request_usd
    end

    test "a text row with none of the four extra dimensions leaves them all nil" do
      sync([ or_model(id: "anthropic/claude-haiku-4.5", name: "Anthropic: Claude Haiku 4.5",
                      prompt: "0.000001", completion: "0.000005") ])

      price = AiModel.find_by!(openrouter_id: "anthropic/claude-haiku-4.5").current_price
      assert_nil price.cache_write_per_mtok
      assert_nil price.audio_input_per_mtok
      assert_nil price.image_input_usd
      assert_nil price.request_usd
    end

    test "a change in input_cache_write alone writes a new snapshot" do
      id = "anthropic/claude-haiku-4.5"
      sync([ or_model(id: id, name: "Anthropic: Claude Haiku 4.5",
                      prompt: "0.000001", completion: "0.000005",
                      cache_write: "0.00000125") ])
      model = AiModel.find_by!(openrouter_id: id)
      assert_equal 1, model.price_points.count

      result = sync([ or_model(id: id, name: "Anthropic: Claude Haiku 4.5",
                               prompt: "0.000001", completion: "0.000005",
                               cache_write: "0.0000025") ],
                    today: Date.current + 1)

      assert_equal 1, result.repriced
      assert_equal 2, model.reload.price_points.count
      assert_equal 2.5, model.current_price.cache_write_per_mtok
      # The headline rates didn't move, so the Slack digest gets no misleading
      # "$X→$X · +0.0%" reprice line for the cache-write-only change.
      assert_empty result.repriced_records
    end

    # --- editorial generation ----------------------------------------------

    # A describer test double standing in for AiModel::Description. Records
    # the kwargs it was called with and returns a fixed editorial hash (or a
    # caller-supplied one), so we never touch the Anthropic API.
    class FakeDescriber
      attr_reader :calls

      def initialize(copy: nil, &block)
        @copy  = copy
        @block = block
        @calls = []
      end

      def generate(**kwargs)
        @calls << kwargs
        return @block.call(**kwargs) if @block

        @copy || {
          description: "A generated one-liner.",
          strengths:   "Generated strengths.",
          best_for:    "Generated best-for.",
          limitations: "Generated limitations."
        }
      end
    end

    test "a newly created model gets generated editorial copy, replacing the upstream blurb" do
      describer = FakeDescriber.new
      sync([ or_model(id: "newlab/wonder-1", name: "NewLab: Wonder 1",
                      prompt: "0.0000001", completion: "0.0000004",
                      description: "Upstream blurb that is probably truncated and…") ],
           describer: describer)

      model = AiModel.find_by!(openrouter_id: "newlab/wonder-1")
      assert_equal "A generated one-liner.", model.description
      assert_equal "Generated strengths.",   model.strengths
      assert_equal "Generated best-for.",     model.best_for
      assert_equal "Generated limitations.",  model.limitations

      # Called once, with the model facts and the upstream blurb as a hint.
      assert_equal 1, describer.calls.size
      call = describer.calls.first
      assert_equal "Wonder 1", call[:name]
      assert_equal "NewLab",   call[:provider]
      assert_match "Upstream blurb", call[:source_text]
    end

    test "a written-up model is not regenerated on re-sync" do
      describer = FakeDescriber.new
      rows = [ or_model(id: "newlab/wonder-1", name: "NewLab: Wonder 1",
                        prompt: "0.0000001", completion: "0.0000004") ]

      sync(rows, describer: describer)
      sync(rows, today: Date.current + 1, describer: describer)

      assert_equal 1, describer.calls.size,
                   "a model that already has editorial copy must not regenerate"
    end

    test "a model whose first generation failed is retried on a later sync" do
      rows = [ or_model(id: "newlab/wonder-1", name: "NewLab: Wonder 1",
                        prompt: "0.0000001", completion: "0.0000004") ]

      # Day one: generation raises, so the model is created without editorial copy.
      sync(rows, describer: FakeDescriber.new { |**| raise "boom" })
      model = AiModel.find_by!(openrouter_id: "newlab/wonder-1")
      assert_nil model.strengths

      # Day two: generation works, so the still-blank model gets written up.
      good = FakeDescriber.new
      sync(rows, today: Date.current + 1, describer: good)

      assert_equal 1, good.calls.size
      assert_equal "Generated strengths.", model.reload.strengths
    end

    test "generation is capped per sync run, leaving the overflow for later" do
      over = ModelSync::MAX_GENERATED_PER_RUN + 3
      rows = (1..over).map do |i|
        or_model(id: "newlab/wonder-#{i}", name: "NewLab: Wonder #{i}",
                 prompt: "0.0000001", completion: "0.0000004")
      end
      describer = FakeDescriber.new

      sync(rows, describer: describer)

      assert_equal ModelSync::MAX_GENERATED_PER_RUN, describer.calls.size
      # Every model is still created — only the write-up is deferred.
      assert_equal over, AiModel.from_openrouter.where("openrouter_id LIKE 'newlab/wonder-%'").count
      assert_equal over - ModelSync::MAX_GENERATED_PER_RUN,
                   AiModel.from_openrouter.where("openrouter_id LIKE 'newlab/wonder-%'")
                          .where(strengths: [ nil, "" ]).count
    end

    test "a written-up model keeps its generated description across syncs" do
      # A model we've already written up: a clean generated description + facets.
      model = AiModel.create!(
        provider: providers(:anthropic), source: AiModel::OPENROUTER_SOURCE,
        name: "Wonder Pre", slug: "anthropic-wonder-pre", status: "active", tier: "mid",
        openrouter_id: "anthropic/wonder-pre",
        description: "A clean generated sentence.",
        strengths: "S.", best_for: "B.", limitations: "L."
      )

      # A later sync brings the (truncated) upstream blurb again. Generation off.
      sync([ or_model(id: "anthropic/wonder-pre", name: "Anthropic: Wonder Pre",
                      prompt: "0.000001", completion: "0.000002",
                      description: "Upstream blurb that is truncated…") ],
           today: Date.current + 1, describer: nil)

      assert_equal "A clean generated sentence.", model.reload.description,
                   "enrich must not revert a written-up model's description to the upstream blurb"
    end

    test "a generation failure falls back to the upstream description" do
      raising = FakeDescriber.new { |**| raise "boom" }

      assert_nothing_raised do
        sync([ or_model(id: "newlab/wonder-1", name: "NewLab: Wonder 1",
                        prompt: "0.0000001", completion: "0.0000004",
                        description: "Plain upstream description.") ],
             describer: raising)
      end

      model = AiModel.find_by!(openrouter_id: "newlab/wonder-1")
      assert_equal "Plain upstream description.", model.description
      assert_nil model.strengths
    end

    test "curated duplicates are never sent to the describer" do
      describer = FakeDescriber.new
      # Duplicates curated `opus` (Claude Opus 4.8) -> skipped, never created.
      sync([ or_model(id: "anthropic/claude-opus-4.8", name: "Anthropic: Claude Opus 4.8",
                      prompt: "0.000005", completion: "0.000025") ],
           describer: describer)

      assert_empty describer.calls
    end
  end
end
