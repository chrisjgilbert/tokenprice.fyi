require "bigdecimal"
require "set"

module OpenRouter
  # Imports the OpenRouter catalogue into our Provider / AiModel / PricePoint
  # schema. Designed to run daily and to sit alongside hand-curated data and
  # other future sources, so it follows three rules:
  #
  #   1. Augment, don't replace. New OpenRouter models are added; a model that
  #      duplicates a curated one (same provider, same normalised name) is left
  #      to the curated record.
  #   2. Never clobber curated data. Rows with source "manual" keep their
  #      hand-written metadata; only genuinely blank fields are ever filled, and
  #      their authoritative price history is never touched unless an admin has
  #      explicitly linked the row via `openrouter_id`.
  #   3. Keep the append-only history honest. A new PricePoint is written only
  #      when the price actually moved since the last snapshot.
  #
  #   OpenRouter::ModelSync.call  # => #<Result created=12 enriched=40 ...>
  class ModelSync
    PER_MTOK           = 1_000_000
    PRICE_SOURCE_LABEL = "openrouter.ai".freeze

    # Imported models land in a neutral tier and a human re-curates from there.
    # Tier here means capability, which OpenRouter doesn't expose and price can't
    # reliably stand in for (plenty of cheap frontier models, pricey small ones),
    # so guessing would just produce confidently-wrong labels. "mid" also keeps a
    # bulk import out of the cheapest-frontier headline, which only ranks
    # frontier-tier models.
    DEFAULT_TIER = "mid".freeze

    # Defensive cap on the free-text description we copy from an untrusted API.
    DESCRIPTION_LIMIT = 10_000

    # Description generation is a blocking, per-model Anthropic call. Capping how
    # many run per sync keeps the first run after deploy — when every OpenRouter
    # model is new — from firing hundreds of serial API calls on the daily job's
    # critical path. Models over the cap (and any whose generation fails) are
    # left without editorial copy and picked up on later runs, since
    # `generate_editorial` re-attempts any owned row still missing it. For a bulk
    # one-off, the `openrouter:backfill_descriptions` rake task ignores this cap.
    MAX_GENERATED_PER_RUN = 25

    # Patterns for OpenRouter variant models that duplicate a versioned entry.
    LATEST_NAME_RE = /\blatest\b/i
    LATEST_ID_RE   = /:latest\b/i
    FAST_ID_RE     = /:fast\b/i
    # Some speed variants arrive with the ":fast" marker only in their display
    # name (e.g. "Anthropic: Claude Opus 4.7 (Fast)") while the id stays plain.
    # Match the parenthetical "(Fast)" suffix specifically so genuinely
    # distinct models like "Grok 4.1 Fast" are left alone.
    FAST_NAME_RE   = /\(\s*fast\s*\)/i

    # OpenRouter id namespaces mapped onto the providers we already curate, so
    # synced models attach to them instead of spawning duplicate providers.
    PROVIDER_SLUGS = {
      "anthropic"  => "anthropic",
      "openai"     => "openai",
      "google"     => "google",
      "x-ai"       => "xai",
      "deepseek"   => "deepseek",
      "meta-llama" => "meta",
      "mistralai"  => "mistral",
      "qwen"       => "alibaba",
      "moonshotai" => "moonshot-ai"
    }.freeze

    # Country headquarters for OpenRouter namespaces not already covered by
    # seeds. Used to place newly-discovered providers on the map. Seeded
    # providers (those in PROVIDER_SLUGS) get their country from db/seeds.rb,
    # so they are intentionally absent here. Community / individual fine-tuners
    # (e.g. gryphe, thedrummer, undi95, sao10k) are omitted — they appear in
    # the "not yet placed on the map" section until set via the admin UI.
    PROVIDER_COUNTRIES = {
      # — United States —
      "allenai"         => { country: "United States",        country_code: "US" },
      "amazon"          => { country: "United States",        country_code: "US" },
      "arcee-ai"        => { country: "United States",        country_code: "US" },
      "databricks"      => { country: "United States",        country_code: "US" },
      "essentialai"     => { country: "United States",        country_code: "US" },
      "fireworks"       => { country: "United States",        country_code: "US" },
      "ibm"             => { country: "United States",        country_code: "US" },
      "inflection"      => { country: "United States",        country_code: "US" },
      "liquid"          => { country: "United States",        country_code: "US" },
      "microsoft"       => { country: "United States",        country_code: "US" },
      "nousresearch"    => { country: "United States",        country_code: "US" },
      "nvidia"          => { country: "United States",        country_code: "US" },
      "openrouter"      => { country: "United States",        country_code: "US" },
      "perplexity"      => { country: "United States",        country_code: "US" },
      "sambanova"       => { country: "United States",        country_code: "US" },
      "together"        => { country: "United States",        country_code: "US" },
      "writer"          => { country: "United States",        country_code: "US" },
      # — China —
      "01-ai"           => { country: "China",                country_code: "CN" },
      "baidu"           => { country: "China",                country_code: "CN" },
      "bytedance"       => { country: "China",                country_code: "CN" },
      "bytedance-seed"  => { country: "China",                country_code: "CN" },
      "inclusionai"     => { country: "China",                country_code: "CN" },
      "kwaipilot"       => { country: "China",                country_code: "CN" },
      "minimax"         => { country: "China",                country_code: "CN" },
      "stepfun"         => { country: "China",                country_code: "CN" },
      "tencent"         => { country: "China",                country_code: "CN" },
      "xiaomi"          => { country: "China",                country_code: "CN" },
      "zhipu"           => { country: "China",                country_code: "CN" },
      # — Rest of world —
      "ai21"            => { country: "Israel",               country_code: "IL" },
      "aionlabs"        => { country: "Israel",               country_code: "IL" },
      "aleph-alpha"     => { country: "Germany",              country_code: "DE" },
      "cohere"          => { country: "Canada",               country_code: "CA" },
      "inception"       => { country: "United Arab Emirates", country_code: "AE" },
      "rekaai"          => { country: "Singapore",            country_code: "SG" },
      "upstage"         => { country: "South Korea",          country_code: "KR" }
    }.freeze

    # Captures a newly-created model for the Slack digest.
    CreatedRecord = Data.define(:model_name, :provider_name, :model_slug, :new_provider,
                                :input_per_mtok, :output_per_mtok)

    # Captures a repriced model with old/new pricing for the Slack digest.
    RepricedRecord = Data.define(:model_name, :provider_name, :model_slug,
                                 :old_input, :old_output, :old_cached,
                                 :new_input, :new_output, :new_cached,
                                 :pct_input_change)

    Result = Struct.new(:created, :enriched, :repriced, :skipped,
                        :created_records, :repriced_records,
                        keyword_init: true) do
      def to_s
        "OpenRouter sync: #{created} created, #{enriched} enriched, " \
          "#{repriced} repriced, #{skipped} skipped"
      end
    end

    def self.call(...) = new(...).call

    def initialize(client: Client.new, today: Date.current,
                   describer: AiModel::Description.new, logger: Rails.logger)
      @client    = client
      @today     = today
      @describer = describer
      @logger    = logger
      @generated = 0
      @result    = Result.new(created: 0, enriched: 0, repriced: 0, skipped: 0,
                              created_records: [], repriced_records: [])
    end

    def call
      catalog = @client.models
      @logger.info("OpenRouter sync: fetched #{catalog.size} models")

      retire_latest_aliases
      retire_speed_variants

      catalog.each do |row|
        outcome =
          begin
            import(row)
          rescue => e
            @logger.error("OpenRouter sync: #{row["id"].inspect} failed — #{e.class}: #{e.message}")
            :skipped
          end
        @result[outcome] += 1
      end

      @logger.info(@result.to_s)
      @result
    end

    private

    # Returns the outcome symbol: :created, :enriched, :repriced or :skipped.
    #
    # A per-token PricePoint is written only for a text-output model with a
    # per-token price; it is NEVER written for a non-text-output row, as it would
    # read as a misleading $0. A directory-class row (image generation) is still
    # admitted when it has no usable per-token price — listed "not yet tracked"
    # until its per-image price is curated. Everything else un-priceable
    # (free / malformed text rows) is skipped.
    def import(row)
      return :skipped if latest_alias?(row)
      return :skipped if speed_variant?(row)

      pricing = parse_pricing(row["pricing"])

      # Cheap pre-check off the raw row so a genuinely un-priceable, non-directory
      # row (free text, an unhandled media class) is dropped before we create a
      # provider for it. The authoritative check below uses the model's own
      # (possibly curated) signature after enrich.
      return :skipped if pricing.nil? && !row_directory_class?(row)

      provider, new_provider = resolve_provider(row)
      model                  = find_or_build_model(row, provider)
      return :skipped if model.nil? # duplicates a curated model — leave it be

      created = model.new_record?
      enrich(model, row)

      directory = ModalityClass.directory_class?(model.modality_class)

      # A missing/blank output modality is treated as text (the lenient default),
      # so a normal model whose architecture OpenRouter omitted is still priced.
      # A per-token price is recorded only for a text-output model that has one;
      # a directory-class row keeps whatever price it has (Google prices its
      # image model per token) but is otherwise left price-less.
      prices_per_token = pricing && (model.output_modalities.empty? || model.output_modalities.include?("text"))

      # Admit a row only if it's priceable text OR a directory class we list
      # without a price. A price-less, non-directory row (free text, or an
      # unhandled media class) stays out.
      return :skipped unless prices_per_token || directory

      generate_editorial(model)
      model.save!

      repriced_from = (record_price(model, pricing) if prices_per_token)

      if created
        # Directory-class creations carry no headline price, so they're left out
        # of the digest (which formats per-token rates) rather than posting "$0".
        if prices_per_token
          @result.created_records << CreatedRecord.new(
            model_name:      model.name,
            provider_name:   provider.name,
            model_slug:      model.slug,
            new_provider:    new_provider,
            input_per_mtok:  pricing[:input],
            output_per_mtok: pricing[:output]
          )
        end
        :created
      elsif repriced_from   # Hash of old pricing — truthy only when repriced
        # A snapshot was written, but the Slack digest only reports the headline
        # rates. Announce a reprice only when one of those actually moved — an
        # extra-dimension-only change (e.g. cache write) would otherwise post a
        # confusing "$3→$3 · +0.0%" line.
        if headline_moved?(repriced_from, pricing)
          old_input = repriced_from[:input].to_f
          pct = old_input.nonzero? ? ((pricing[:input] - old_input) / old_input * 100).round(1) : 0.0

          @result.repriced_records << RepricedRecord.new(
            model_name:    model.name,
            provider_name: provider.name,
            model_slug:    model.slug,
            old_input:     repriced_from[:input],
            old_output:    repriced_from[:output],
            old_cached:    repriced_from[:cached],
            new_input:     pricing[:input],
            new_output:    pricing[:output],
            new_cached:    pricing[:cached],
            pct_input_change: pct
          )
        end
        :repriced
      else
        :enriched
      end
    end

    # Did a headline rate (input / output / cached) move? The extra billing
    # dimensions still write a snapshot, but they aren't carried in the digest.
    def headline_moved?(old, new)
      old[:input] != new[:input] ||
        old[:output] != new[:output] ||
        (old[:cached] || 0) != (new[:cached] || 0)
    end

    # --- pricing -----------------------------------------------------------

    # OpenRouter quotes USD per token as strings; we store USD per 1M tokens.
    # Returns nil for un-priceable (free / malformed) rows so they're skipped.
    def parse_pricing(pricing)
      return nil unless pricing.is_a?(Hash)

      input  = to_mtok(pricing["prompt"])
      output = to_mtok(pricing["completion"])
      return nil if input.nil? || output.nil?
      return nil if input.zero? && output.zero?

      {
        input:       input,
        output:      output,
        cached:      zero_to_nil(to_mtok(pricing["input_cache_read"])),
        # Extra dimensions OpenRouter carries on text-output rows. image/request
        # are a flat USD charge (to_usd), not a per-token rate. 0/blank reads as
        # "not charged", so it's nil'd like cached.
        cache_write: zero_to_nil(to_mtok(pricing["input_cache_write"])),
        audio_input: zero_to_nil(to_mtok(pricing["audio"])),
        image_input: zero_to_nil(to_usd(pricing["image"])),
        request:     zero_to_nil(to_usd(pricing["request"]))
      }
    end

    def zero_to_nil(value)
      value unless value&.zero?
    end

    # Per-token rate scaled to USD per 1M tokens.
    def to_mtok(value)
      d = parse_decimal(value)
      (d * PER_MTOK).round(6) if d
    end

    # Raw USD, no per-1M scaling — for the per-image / per-request dimensions
    # OpenRouter quotes as a flat charge rather than a per-token rate.
    def to_usd(value)
      parse_decimal(value)&.round(6)
    end

    def parse_decimal(value)
      return nil if value.nil? || value.to_s.strip.empty?

      BigDecimal(value.to_s)
    rescue ArgumentError
      nil
    end

    # Reads one side of a row's modality signature from `architecture`, through
    # the same normalisation the classifier uses, so the stored order is
    # deterministic. A missing/blank architecture yields [], which downstream
    # degrades to the `text` class.
    def modality_signature(row, key)
      ModalityClass.normalize(row.dig("architecture", key))
    end

    # Whether the raw row's signature classifies as a directory class (image
    # generation) we list without a per-token price. Read off the row so a
    # price-less row can be dropped before a provider is ever created for it.
    def row_directory_class?(row)
      klass = ModalityClass.for(input: modality_signature(row, "input_modalities"),
                                output: modality_signature(row, "output_modalities"))
      ModalityClass.directory_class?(klass)
    end

    # Append a snapshot only when the price moved. If it moved twice in one day,
    # today's snapshot is updated in place (the [model, date] index is unique).
    #
    # Returns:
    #   false  — price unchanged (no snapshot written)
    #   nil    — first-ever price snapshot (no old pricing to compare)
    #   Hash   — repriced; value is the old pricing { input:, output:, cached: }
    def record_price(model, pricing)
      current = model.current_price
      return false if current && same_price?(current, pricing)

      old_pricing = current ? {
        input:  current.input_per_mtok,
        output: current.output_per_mtok,
        cached: current.cached_input_per_mtok
      } : nil

      point = model.price_points.find_or_initialize_by(effective_on: @today)
      point.assign_attributes(
        input_per_mtok:        pricing[:input],
        output_per_mtok:       pricing[:output],
        cached_input_per_mtok: pricing[:cached],
        cache_write_per_mtok:  pricing[:cache_write],
        audio_input_per_mtok:  pricing[:audio_input],
        image_input_usd:       pricing[:image_input],
        request_usd:           pricing[:request],
        source:                PRICE_SOURCE_LABEL
      )
      point.note ||= "Imported from OpenRouter"
      point.save!
      model.forget_price_cache!

      old_pricing  # nil = first price, Hash = repriced
    end

    def same_price?(point, pricing)
      point.input_per_mtok == pricing[:input] &&
        point.output_per_mtok == pricing[:output] &&
        # A missing cached tier reads back as nil from our own rows but may be a
        # stored 0 on a curated/linked row — treat the two alike so an
        # unchanged price never churns a fresh snapshot every day. The four extra
        # dimensions get the same nil/0 normalisation so a change in any one alone
        # (e.g. cache-write only) counts as a reprice and lands a fresh snapshot.
        (point.cached_input_per_mtok || 0) == (pricing[:cached] || 0) &&
        (point.cache_write_per_mtok || 0) == (pricing[:cache_write] || 0) &&
        (point.audio_input_per_mtok || 0) == (pricing[:audio_input] || 0) &&
        (point.image_input_usd || 0) == (pricing[:image_input] || 0) &&
        (point.request_usd || 0) == (pricing[:request] || 0)
    end

    # --- providers & models ------------------------------------------------

    # Returns [provider, new_provider_boolean].
    def resolve_provider(row)
      namespace    = namespace_of(row)
      slug         = PROVIDER_SLUGS[namespace] || namespace.parameterize
      geo          = PROVIDER_COUNTRIES[namespace]
      new_provider = false

      provider = Provider.find_or_create_by!(slug: slug) do |p|
        new_provider       = true
        p.name             = provider_name(namespace, row)
        p.website          = "https://openrouter.ai/#{namespace}"
        p.country          = geo[:country]      if geo
        p.country_code     = geo[:country_code] if geo
      end

      if geo && provider.country_code.blank?
        provider.update!(country: geo[:country], country_code: geo[:country_code])
      end

      [ provider, new_provider ]
    end

    def find_or_build_model(row, provider)
      existing = AiModel.find_by(openrouter_id: row["id"])
      return existing if existing

      # A curated row already covers this model — don't create a parallel entry.
      return nil if curated_duplicate?(provider, row)

      AiModel.new(
        openrouter_id: row["id"],
        provider:      provider,
        source:        AiModel::OPENROUTER_SOURCE,
        name:          model_name(row),
        slug:          unique_slug(row["id"]),
        status:        "active",
        tier:          DEFAULT_TIER
      )
    end

    # Fill metadata from OpenRouter. For rows it owns the importer keeps the
    # data fresh; for an admin-linked curated row it only fills genuine blanks.
    def enrich(model, row)
      desc     = row["description"].presence&.truncate(DESCRIPTION_LIMIT)
      context  = row.dig("top_provider", "context_length") || row["context_length"]
      max_out  = row.dig("top_provider", "max_completion_tokens")
      released = (Time.at(row["created"].to_i).utc.to_date if row["created"].present?)
      inputs   = modality_signature(row, "input_modalities")
      outputs  = modality_signature(row, "output_modalities")

      if model.source == AiModel::OPENROUTER_SOURCE
        # Refresh from upstream only until we've written the model up ourselves.
        # Once it has generated editorial copy, that description is authoritative
        # and must survive later syncs — the upstream blurb is often truncated,
        # so refreshing it would revert our generated description every run.
        model.description    = desc if desc && !written_up?(model)
        model.context_window = context if context
        model.max_output_tokens = max_out if max_out
        # Guarded like the fields above: a payload that omits `architecture`
        # mustn't wipe a previously-recorded signature to [].
        model.input_modalities  = inputs  if inputs.present?
        model.output_modalities = outputs if outputs.present?
      else
        model.description    ||= desc
        model.context_window ||= context
        model.max_output_tokens ||= max_out
        model.input_modalities  = inputs  if model.input_modalities.blank?
        model.output_modalities = outputs if model.output_modalities.blank?
      end

      # `created` is when OpenRouter listed the model, only an approximation of
      # the release date, so set it once and never churn it.
      model.released_on ||= released
    end

    # A model we've already written editorial copy for. Its description and
    # facets are authoritative — neither the upstream blurb (enrich) nor a fresh
    # generation should overwrite them. The facets are written together, so the
    # presence of `strengths` marks the whole write-up as done.
    def written_up?(model)
      model.strengths.present?
    end

    # Replace the (often truncated) upstream blurb with a generated editorial
    # write-up in the catalogue's own voice — the same description +
    # strengths/best-for/limitations shape as the curated rows. Runs for any row
    # we own that is still missing editorial copy (its `strengths` facet), so a
    # model whose generation failed on a previous run is retried on the next one
    # rather than keeping the truncated blurb forever. A `strengths` facet means
    # it has already been written up, so the work happens once per model.
    # Best-effort: a generation failure leaves the upstream description in place
    # rather than failing the import (which would skip the model entirely).
    def generate_editorial(model)
      return unless @describer
      return unless model.source == AiModel::OPENROUTER_SOURCE
      return if written_up?(model)
      return if generation_capped?

      @generated += 1
      copy = @describer.generate(
        name:           model.name,
        provider:       model.provider.name,
        context_window: model.context_window,
        source_text:    model.description.presence
      )
      return if copy.blank?

      model.description = copy[:description] if copy[:description].present?
      model.strengths   = copy[:strengths]
      model.best_for    = copy[:best_for]
      model.limitations = copy[:limitations]
    rescue => e
      @logger.warn("OpenRouter sync: description generation failed for " \
                   "#{model.openrouter_id.inspect} — #{e.class}: #{e.message}")
    end

    # Whether this run has hit its description-generation cap. Logs once when the
    # cap is first reached so a backlog is visible without spamming the log.
    def generation_capped?
      return false if @generated < MAX_GENERATED_PER_RUN

      unless @generation_cap_logged
        @logger.info("OpenRouter sync: reached the #{MAX_GENERATED_PER_RUN}/run " \
                     "description-generation cap; remaining models will be written up on later runs")
        @generation_cap_logged = true
      end
      true
    end

    # --- naming & dedup ----------------------------------------------------

    def namespace_of(row)
      row["id"].to_s.split("/").first.to_s
    end

    def provider_name(namespace, row)
      # OpenRouter names read "Anthropic: Claude 3.5 Sonnet" — the prefix is the
      # provider's display name. Without the colon the whole string is the model
      # name, not the provider's, so fall back to the namespace instead.
      name = row["name"].to_s
      prefix = name.split(":", 2).first if name.include?(":")
      prefix.presence&.strip || namespace.tr("-", " ").split.map(&:capitalize).join(" ")
    end

    def model_name(row)
      raw = row["name"].to_s
      name = raw.include?(":") ? raw.split(":", 2).last.strip : raw.strip
      name.presence || row["id"].to_s
    end

    # "Latest" aliases (e.g. "Claude Opus Latest", "GPT-4o Latest") are
    # floating pointers to whatever the current versioned model happens to
    # be. They duplicate a versioned entry and confuse the pricing table.
    def latest_alias?(row)
      model_name(row).match?(LATEST_NAME_RE) || row["id"].to_s.match?(LATEST_ID_RE)
    end

    def retire_latest_aliases
      ids = AiModel.from_openrouter.where.not(status: "retired")
        .pluck(:id, :name, :openrouter_id)
        .select { |_, name, oid| name.match?(LATEST_NAME_RE) || oid.to_s.match?(LATEST_ID_RE) }
        .map(&:first)
      return if ids.empty?

      retired = AiModel.where(id: ids).update_all(status: "retired")
      @logger.info("OpenRouter sync: retired #{retired} 'Latest' alias(es)")
    end

    # Speed variants (e.g. "anthropic/claude-opus-4.8:fast", or a plain id
    # named "Claude Opus 4.7 (Fast)") are the same model billed at a premium
    # for faster output. They duplicate a versioned entry with inflated
    # pricing and confuse comparisons.
    def speed_variant?(row)
      row["id"].to_s.match?(FAST_ID_RE) || row["name"].to_s.match?(FAST_NAME_RE)
    end

    def retire_speed_variants
      ids = AiModel.from_openrouter.where.not(status: "retired")
        .pluck(:id, :name, :openrouter_id)
        .select { |_, name, oid| oid.to_s.match?(FAST_ID_RE) || name.to_s.match?(FAST_NAME_RE) }
        .map(&:first)
      return if ids.empty?

      retired = AiModel.where(id: ids).update_all(status: "retired")
      @logger.info("OpenRouter sync: retired #{retired} speed variant(s)")
    end

    def curated_duplicate?(provider, row)
      names = curated_names[provider.id]
      names&.include?(normalize(model_name(row))) || false
    end

    # provider_id => Set of normalised curated model names, built once.
    def curated_names
      @curated_names ||= AiModel.curated.pluck(:provider_id, :name)
        .each_with_object(Hash.new { |h, k| h[k] = Set.new }) do |(pid, name), index|
          index[pid] << normalize(name)
        end
    end

    def normalize(string)
      string.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end

    # Slug from the globally-unique OpenRouter id, disambiguated if it ever
    # collides (e.g. ":free"/":beta" variants parameterise to the same string).
    def unique_slug(openrouter_id)
      base = openrouter_id.to_s.parameterize.presence || "model"
      slug = base
      n    = 2
      while AiModel.exists?(slug: slug)
        slug = "#{base}-#{n}"
        n += 1
      end
      slug
    end
  end
end
