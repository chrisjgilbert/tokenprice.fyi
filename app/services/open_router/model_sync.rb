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
    DESCRIPTION_LIMIT = 2_000

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

    Result = Struct.new(:created, :enriched, :repriced, :skipped, keyword_init: true) do
      def to_s
        "OpenRouter sync: #{created} created, #{enriched} enriched, " \
          "#{repriced} repriced, #{skipped} skipped"
      end
    end

    def self.call(...) = new(...).call

    def initialize(client: Client.new, today: Date.current, logger: Rails.logger)
      @client = client
      @today  = today
      @logger = logger
      @result = Result.new(created: 0, enriched: 0, repriced: 0, skipped: 0)
    end

    def call
      catalog = @client.models
      @logger.info("OpenRouter sync: fetched #{catalog.size} models")

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
    def import(row)
      pricing = parse_pricing(row["pricing"])
      return :skipped unless pricing && text_output?(row)

      provider = resolve_provider(row)
      model    = find_or_build_model(row, provider)
      return :skipped if model.nil? # duplicates a curated model — leave it be

      created = model.new_record?
      enrich(model, row)
      model.save!

      repriced = record_price(model, pricing)

      if created    then :created
      elsif repriced then :repriced
      else :enriched
      end
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

      cached = to_mtok(pricing["input_cache_read"])
      cached = nil if cached&.zero? # treat "no cached tier" and 0 alike

      { input: input, output: output, cached: cached }
    end

    def to_mtok(value)
      return nil if value.nil? || value.to_s.strip.empty?

      (BigDecimal(value.to_s) * PER_MTOK).round(6)
    rescue ArgumentError
      nil
    end

    # We track text-generation pricing, so skip embedding / image-only models.
    # Be lenient: if the architecture is missing, assume text.
    def text_output?(row)
      modalities = row.dig("architecture", "output_modalities")
      modalities.blank? || Array(modalities).include?("text")
    end

    # Append a snapshot only when the price moved. If it moved twice in one day,
    # today's snapshot is updated in place (the [model, date] index is unique).
    def record_price(model, pricing)
      current = model.current_price
      return false if current && same_price?(current, pricing)

      point = model.price_points.find_or_initialize_by(effective_on: @today)
      point.assign_attributes(
        input_per_mtok:        pricing[:input],
        output_per_mtok:       pricing[:output],
        cached_input_per_mtok: pricing[:cached],
        source:                PRICE_SOURCE_LABEL
      )
      point.note ||= "Imported from OpenRouter"
      point.save!
      model.forget_price_cache!
      true
    end

    def same_price?(point, pricing)
      point.input_per_mtok == pricing[:input] &&
        point.output_per_mtok == pricing[:output] &&
        # A missing cached tier reads back as nil from our own rows but may be a
        # stored 0 on a curated/linked row — treat the two alike so an
        # unchanged price never churns a fresh snapshot every day.
        (point.cached_input_per_mtok || 0) == (pricing[:cached] || 0)
    end

    # --- providers & models ------------------------------------------------

    def resolve_provider(row)
      namespace = namespace_of(row)
      slug      = PROVIDER_SLUGS[namespace] || namespace.parameterize

      Provider.find_or_create_by!(slug: slug) do |p|
        p.name    = provider_name(namespace, row)
        p.website = "https://openrouter.ai/#{namespace}"
      end
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

      if model.source == AiModel::OPENROUTER_SOURCE
        model.description    = desc if desc
        model.context_window = context if context
        model.max_output_tokens = max_out if max_out
      else
        model.description    ||= desc
        model.context_window ||= context
        model.max_output_tokens ||= max_out
      end

      # `created` is when OpenRouter listed the model, only an approximation of
      # the release date, so set it once and never churn it.
      model.released_on ||= released
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
