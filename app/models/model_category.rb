# ModelCategory — the pricing families the models table tabs between. Language
# models bill per token (input/output/cached); embeddings bill per input token
# only (the output is a vector, sized by `dimensions`); image generation bills
# natively (per image, credits, …). Each needs its own columns, sorts, and SEO,
# so splitting them into their own indexable URLs is what this registry drives.
#
# A plain-Ruby domain PORO in the ModalityClass idiom: a
# Data.define value object with a frozen, ordered registry. Adding a later tab
# (speech, video, …) is a registry addition plus a route — the controller, view,
# and sitemap read everything they need off the category.
class ModelCategory
  # `matcher` decides membership from a model's modality_class (symbol). Every
  # NON-language category declares its own, so adding a tab never touches
  # language: language's matcher is nil and it claims whatever no other category
  # does (`member?` → `ModelCategory.unclaimed?`). `columns` is the ordered
  # left→right list of column keys the view renders — the one source of truth for
  # the per-category table shape, replacing the old token/native boolean.
  # `path_name` is the Rails route-helper prefix the link/canonical is built from
  # (:root → root_path/root_url, :embeddings → embeddings_path/_url).
  Category = Data.define(
    :slug, :label, :param, :path_name,
    :sorts, :default_sort, :default_dir,
    :title, :meta_description, :matcher, :columns
  ) do
    def member?(modality_class)
      mc = modality_class.to_sym
      matcher ? matcher.call(mc) : ModelCategory.unclaimed?(mc)
    end

    # The empty-state row spans every column plus the leading select and trailing
    # go columns the layout always renders.
    def table_colspan = columns.size + 2
  end

  # Language is the fallback: every listed model whose class no other tab claims
  # (text, multimodal, omnimodal, …). A nil matcher plus the `unclaimed?` check
  # means a future native-priced class doesn't fall onto the per-token table
  # before it has its own tab. It leads the strip and owns the root URL, so a
  # bare visit lands on the per-token table.
  LANGUAGE = Category.new(
    slug: "language",
    label: "Language models",
    param: "language",
    path_name: :root,
    sorts: %w[input output cached context name released],
    default_sort: "output",
    default_dir: "desc",
    title: "LLM API token prices, per model — tokenprice.fyi",
    meta_description: "LLM API token prices for Claude, GPT-5, Gemini, Grok, and DeepSeek. " \
                      "Input, output, and cached rates per 1M tokens, updated daily.",
    matcher: nil,
    columns: %i[name input output cached context released]
  )

  # Embeddings bill per input token only — the output is a vector, so there is no
  # output or cached rate. `dimensions` is that vector's size, shown instead. The
  # default sort is cheapest input first.
  EMBEDDINGS = Category.new(
    slug: "embeddings",
    label: "Embeddings",
    param: "embeddings",
    path_name: :embeddings,
    sorts: %w[input context name provider released],
    default_sort: "input",
    default_dir: "asc",
    title: "Text embedding API prices, per model — tokenprice.fyi",
    meta_description: "Text embedding model prices, billed per 1M input tokens. " \
                      "Input rates and vector dimensions, updated as providers publish them.",
    matcher: ->(mc) { mc == :embedding },
    columns: %i[name provider input dimensions context released]
  )

  # Rerank completes the retrieval pair with embeddings. It's image-shaped, not
  # embedding-shaped: pricing is split between per-search (Cohere) and per-1M-
  # tokens (Voyage, ZeroEntropy) with no comparable unit, so it uses the
  # heterogeneous price_summary string + pricing_model badge, not a sortable rate.
  RERANK = Category.new(
    slug: "rerank",
    label: "Rerank",
    param: "rerank",
    path_name: :rerank,
    sorts: %w[name provider released],
    default_sort: "name",
    default_dir: "asc",
    title: "Reranker API pricing — tokenprice.fyi",
    meta_description: "Reranker (relevance-scoring) model pricing, in each model's native unit — per search " \
                      "or per 1M tokens. Native rates and pricing models, updated as providers publish them.",
    matcher: ->(mc) { mc == :rerank },
    columns: %i[name provider pricing released]
  )

  # Speech-to-text (transcription) bills against audio duration, not tokens, so
  # the comparable axis is a native per-minute rate (`native_price_usd`, a numeric
  # single-unit price that sorts). The default sort is cheapest per minute first.
  SPEECH_TO_TEXT = Category.new(
    slug: "speech-to-text",
    label: "Speech to text",
    param: "speech-to-text",
    path_name: :speech_to_text,
    sorts: %w[native_price name provider released],
    default_sort: "native_price",
    default_dir: "asc",
    title: "Speech-to-text API pricing, per model — tokenprice.fyi",
    meta_description: "Speech-to-text (transcription) model pricing, billed per minute of audio. " \
                      "Native per-minute rates across providers, updated as they publish them.",
    matcher: ->(mc) { mc == :speech_to_text },
    columns: %i[name provider native_price released]
  )

  # Text-to-speech (synthesis) is speech-to-text-shaped: it bills predominantly
  # per character of input text, which normalizes to a comparable, sortable
  # native rate — USD per 1M characters — so it reuses the same numeric
  # native_price column, sort, and sink. Cheapest per 1M chars first.
  TEXT_TO_SPEECH = Category.new(
    slug: "text-to-speech",
    label: "Text to speech",
    param: "text-to-speech",
    path_name: :text_to_speech,
    sorts: %w[native_price name provider released],
    default_sort: "native_price",
    default_dir: "asc",
    title: "Text-to-speech API pricing, per model — tokenprice.fyi",
    meta_description: "Text-to-speech (speech synthesis) model pricing, billed per 1M characters of input text. " \
                      "Native per-character rates across providers, updated as they publish them.",
    matcher: ->(mc) { mc == :text_to_speech },
    columns: %i[name provider native_price released]
  )

  IMAGE = Category.new(
    slug: "image",
    label: "Image generation",
    param: "image",
    path_name: :image_generation,
    sorts: %w[name provider released],
    default_sort: "name",
    default_dir: "asc",
    title: "Image generation API pricing — tokenprice.fyi",
    meta_description: "Image generation model pricing, billed per image rather than per token. " \
                      "Native per-image rates and pricing models, updated as providers publish them.",
    matcher: ->(mc) { mc == :image_generation },
    columns: %i[name provider pricing released]
  )

  # Video generation is image-generation-shaped: a directory class with
  # heterogeneous native pricing (per second, per clip, resolution/duration/audio
  # tiers, credits), so it reuses image's column set, the :pricing cell, and the
  # price_summary/pricing_model machinery rather than a sortable per-unit rate.
  VIDEO_GENERATION = Category.new(
    slug: "video",
    label: "Video generation",
    param: "video",
    path_name: :video_generation,
    sorts: %w[name provider released],
    default_sort: "name",
    default_dir: "asc",
    title: "Video generation API pricing — tokenprice.fyi",
    meta_description: "Video generation model pricing in each model's native units — per second, per clip, " \
                      "in credits, or in tokens. Native rates and pricing models, updated as providers publish them.",
    matcher: ->(mc) { mc == :video_generation },
    columns: %i[name provider pricing released]
  )

  ALL = [ LANGUAGE, EMBEDDINGS, RERANK, SPEECH_TO_TEXT, TEXT_TO_SPEECH, IMAGE, VIDEO_GENERATION ].freeze

  BY_PARAM = ALL.index_by(&:param).freeze

  # The ordered tab strip.
  def self.all = ALL

  # The default tab a bare or unrecognised request lands on.
  def self.default = LANGUAGE

  # The category for a route/query param, falling back to the default for nil,
  # blank, or an unknown value so a bad param can never 404 the homepage.
  def self.for(param) = BY_PARAM.fetch(param.to_s, default)

  # A modality_class is language's iff no other category's matcher claims it —
  # the seam that keeps language as the fallback without listing every class.
  def self.unclaimed?(mc) = ALL.none? { |c| c.matcher && c.matcher.call(mc) }
end
