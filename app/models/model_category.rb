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

    def shows_tier_facet = columns.include?(:tier)

    # The default (language) tab — the one that owns the root URL and leads the
    # strip. Lets callers ask the domain question without reaching for the route
    # helper prefix (`path_name`).
    def default? = self == ModelCategory.default
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
    sorts: %w[input output cached context name tier],
    default_sort: "output",
    default_dir: "desc",
    title: "LLM API token prices, per model — tokenprice.fyi",
    meta_description: "LLM API token prices for Claude, GPT-5, Gemini, Grok, and DeepSeek. " \
                      "Input, output, and cached rates per 1M tokens, updated daily.",
    matcher: nil,
    columns: %i[name tier input output cached context]
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

  ALL = [ LANGUAGE, EMBEDDINGS, SPEECH_TO_TEXT, IMAGE ].freeze

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
