require "test_helper"

module OpenRouter
  class ModelSyncTest < ActiveSupport::TestCase
    # A stub standing in for OpenRouter::Client — returns a fixed catalogue.
    FakeClient = Struct.new(:rows) { def models = rows }

    # Build an OpenRouter-shaped model hash. Prices are USD *per token* strings,
    # exactly as the real API returns them.
    def or_model(id:, name:, prompt:, completion:, cache_read: "0",
                 context: 200_000, max_out: 8_192, created: 1_700_000_000,
                 input_modalities: [ "text" ], output_modalities: [ "text" ],
                 description: "An OpenRouter model.")
      {
        "id" => id, "name" => name, "created" => created,
        "description" => description, "context_length" => context,
        "architecture" => { "input_modalities" => input_modalities,
                            "output_modalities" => output_modalities },
        "pricing" => { "prompt" => prompt, "completion" => completion,
                       "input_cache_read" => cache_read },
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

    test "creates new models, skips curated duplicates and free/non-text rows" do
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
                 prompt: "0", completion: "0"),
        # Embeddings (non-text output) -> skipped.
        or_model(id: "embedco/embed-1", name: "EmbedCo: Embed 1",
                 prompt: "0.00000002", completion: "0", output_modalities: [ "embedding" ])
      ]

      result = assert_difference("AiModel.count", 2) { sync(rows) }

      assert_equal 2, result.created
      assert_equal 3, result.skipped

      # Curated Opus is untouched: no parallel record, original data intact.
      assert_equal 1, AiModel.where("name = ?", "Claude Opus 4.8").count
      opus = ai_models(:opus).reload
      assert_equal AiModel::MANUAL_SOURCE, opus.source
      assert_equal "Test model.", opus.description
      assert_equal 1, opus.price_points.count

      # Free / embedding rows created neither providers nor models.
      assert_nil Provider.find_by(slug: "freeco")
      assert_nil Provider.find_by(slug: "embedco")
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
