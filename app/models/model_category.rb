# ModelCategory — the pricing families the models table tabs between. Language
# models bill per token (input/output/cached); image generation bills natively
# (per image, credits, …), so the two need different columns, sorts, and SEO.
# Splitting them into their own indexable URLs is what this registry drives.
#
# A plain-Ruby domain PORO in the FeaturePattern / ModalityClass idiom: a
# Data.define value object with a frozen, ordered registry. Adding a later tab
# (embeddings, speech, …) is a registry addition plus a route — the controller,
# view, and sitemap read everything they need off the category.
class ModelCategory
  # `matcher` maps a model's modality_class (symbol) to whether it belongs here,
  # so the split stays data rather than a controller conditional. `path_name` is
  # the Rails route-helper prefix the link/canonical is built from (:root →
  # root_path/root_url, :image_generation → image_generation_path/_url).
  # `matcher` decides membership from a model's modality_class. `token_columns`
  # picks the column layout (per-token vs native price); `shows_tier_facet` and
  # `empty_colspan` are the other bits of layout that vary by category, kept as
  # data here so the view asks the category rather than branching on its slug.
  Category = Data.define(
    :slug, :label, :param, :path_name,
    :sorts, :default_sort, :default_dir,
    :title, :meta_description, :matcher,
    :token_columns, :shows_tier_facet, :empty_colspan
  ) do
    def member?(modality_class) = matcher.call(modality_class.to_sym)
  end

  # Language is the catch-all: every listed model that isn't billed in a native
  # unit (text, multimodal, embedding, omnimodal). It excludes ALL directory
  # classes, not just image, so a future native-priced class (video, …) doesn't
  # fall onto the per-token table before it has its own tab. It leads the strip
  # and owns the root URL, so a bare visit lands on the per-token table.
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
    matcher: ->(modality_class) { !ModalityClass.directory_class?(modality_class) },
    token_columns: true,
    shows_tier_facet: true,
    empty_colspan: 8
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
    matcher: ->(modality_class) { modality_class == :image_generation },
    token_columns: false,
    shows_tier_facet: false,
    empty_colspan: 6
  )

  ALL = [ LANGUAGE, IMAGE ].freeze

  BY_PARAM = ALL.index_by(&:param).freeze

  # The ordered tab strip.
  def self.all = ALL

  # The default tab a bare or unrecognised request lands on.
  def self.default = LANGUAGE

  # The category for a route/query param, falling back to the default for nil,
  # blank, or an unknown value so a bad param can never 404 the homepage.
  def self.for(param) = BY_PARAM.fetch(param.to_s, default)
end
