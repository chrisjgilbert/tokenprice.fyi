require "test_helper"

class ModelListingTest < ActiveSupport::TestCase
  def language
    ModelCategory.for("language")
  end

  def build(category: language, provider_slugs: [], sort: nil, dir: nil, query: "", modalities: [])
    ModelListing.new(
      category: category,
      provider_slugs: provider_slugs,
      sort: sort || category.default_sort,
      dir: dir || category.default_dir,
      query: query,
      modalities: modalities
    )
  end

  test "models excludes retired and price-less rows" do
    names = build.models.map(&:name)
    assert_not_includes names, "Claude Instant 1", "retired rows must never list"
    assert_not_includes names, "Claude No Price", "a price-less text row has nothing to show"
  end

  test "models is scoped to the given category" do
    names = build.models.map(&:name)
    assert_includes names, "Claude Opus 4.8"
    assert_not_includes names, "Test Image Model", "image rows belong to the image tab, not language"

    image_names = build(category: ModelCategory.for("image")).models.map(&:name)
    assert_includes image_names, "Test Image Model"
    assert_not_includes image_names, "Claude Opus 4.8"
  end

  test "provider_slugs filters to the given providers, empty means unfiltered" do
    names = build(provider_slugs: [ "deepseek" ]).models.map(&:name)
    assert_includes names, "DeepSeek V4 Pro"
    assert_not_includes names, "Claude Opus 4.8"

    unfiltered = build(provider_slugs: []).models.map(&:name)
    assert_includes unfiltered, "Claude Opus 4.8"
    assert_includes unfiltered, "DeepSeek V4 Pro"
  end

  test "query filters via AiModel#matches?, blank query is unfiltered" do
    names = build(query: "deepseek").models.map(&:name)
    assert_includes names, "DeepSeek V4 Pro"
    assert_not_includes names, "Claude Opus 4.8"

    unfiltered = build(query: "").models.map(&:name)
    assert_includes unfiltered, "Claude Opus 4.8"
    assert_includes unfiltered, "DeepSeek V4 Pro"
  end

  test "a punctuation-only query is treated as no filter" do
    names = build(query: "!!!").models.map(&:name)
    assert_includes names, "Claude Opus 4.8"
    assert_includes names, "DeepSeek V4 Pro"
  end

  test "a comma-separated query matches any segment" do
    names = build(query: "opus, deepseek").models.map(&:name)
    assert_includes names, "Claude Opus 4.8"
    assert_includes names, "DeepSeek V4 Pro"
  end

  test "modalities filters to the given modality classes, empty means unfiltered" do
    names = build(modalities: [ "multimodal" ]).models.map(&:name)
    assert_includes names, "Guide Sonnet Fixture"
    assert_not_includes names, "DeepSeek V4 Pro"

    unfiltered = build(modalities: []).models.map(&:name)
    assert_includes unfiltered, "Guide Sonnet Fixture"
    assert_includes unfiltered, "DeepSeek V4 Pro"
  end

  test "modality_classes facets the classes present in the category, unaffected by the modality filter itself" do
    unfiltered = build.modality_classes
    assert_includes unfiltered, "multimodal"
    assert_not_includes unfiltered, "image_generation", "image is its own tab, so it never appears as a language facet"

    filtered = build(modalities: [ "multimodal" ]).modality_classes
    assert_equal unfiltered, filtered, "the facet options stay the full set so switching classes remains possible"
  end

  test "models is sorted by the given sort and direction" do
    asc = build(sort: "released", dir: "asc").models
    assert_equal "DeepSeek V4 Pro", asc.first.name

    desc = build(sort: "released", dir: "desc").models
    assert_equal "Claude Fable 5", desc.first.name
  end
end
