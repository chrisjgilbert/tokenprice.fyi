require "test_helper"

class ModelCategoryTest < ActiveSupport::TestCase
  test "for resolves the known params" do
    assert_equal "language", ModelCategory.for("language").slug
    assert_equal "embeddings", ModelCategory.for("embeddings").slug
    assert_equal "speech-to-text", ModelCategory.for("speech-to-text").slug
    assert_equal "image", ModelCategory.for("image").slug
    assert_equal "video", ModelCategory.for("video").slug
  end

  test "for falls back to the language default for nil, blank, or unknown params" do
    assert_equal ModelCategory.default, ModelCategory.for(nil)
    assert_equal ModelCategory.default, ModelCategory.for("")
    assert_equal ModelCategory.default, ModelCategory.for("nonsense")
    assert_equal "language", ModelCategory.default.slug
  end

  test "all is the ordered tab strip: language, embeddings, speech-to-text, image, video" do
    assert_equal %w[language embeddings speech-to-text image video], ModelCategory.all.map(&:slug)
  end

  test "each non-language category claims its class; language is what none claim" do
    image = ModelCategory.for("image")
    embeddings = ModelCategory.for("embeddings")
    language = ModelCategory.for("language")

    assert image.member?(:image_generation)
    refute image.member?(:text)
    refute image.member?(:embedding)

    assert embeddings.member?(:embedding)
    refute embeddings.member?(:image_generation)
    refute embeddings.member?(:text)

    speech = ModelCategory.for("speech-to-text")
    assert speech.member?(:speech_to_text)
    refute speech.member?(:multimodal)
    refute speech.member?(:text)
    refute language.member?(:speech_to_text)

    video = ModelCategory.for("video")
    assert video.member?(:video_generation)
    refute video.member?(:image_generation)
    refute video.member?(:text)
    refute language.member?(:video_generation)

    # Language claims only what no other category matches — not image or embedding.
    refute language.member?(:image_generation)
    refute language.member?(:embedding)
    assert language.member?(:text)
    assert language.member?(:multimodal)
    assert language.member?(:any_to_any)
  end

  test "unclaimed? is true only for classes no non-language matcher claims" do
    assert ModelCategory.unclaimed?(:text)
    assert ModelCategory.unclaimed?(:multimodal)
    assert ModelCategory.unclaimed?(:any_to_any)
    refute ModelCategory.unclaimed?(:embedding)
    refute ModelCategory.unclaimed?(:image_generation)
    refute ModelCategory.unclaimed?(:speech_to_text)
    refute ModelCategory.unclaimed?(:video_generation)
  end

  test "columns and table_colspan describe each category's table shape" do
    assert_equal %i[name tier input output cached context], ModelCategory.for("language").columns
    assert_equal %i[name provider input dimensions context released], ModelCategory.for("embeddings").columns
    assert_equal %i[name provider native_price released], ModelCategory.for("speech-to-text").columns
    assert_equal %i[name provider pricing released], ModelCategory.for("image").columns
    assert_equal %i[name provider pricing released], ModelCategory.for("video").columns

    # colspan = columns + the leading select and trailing go columns.
    assert_equal 8, ModelCategory.for("language").table_colspan
    assert_equal 8, ModelCategory.for("embeddings").table_colspan
    assert_equal 6, ModelCategory.for("speech-to-text").table_colspan
    assert_equal 6, ModelCategory.for("image").table_colspan
    assert_equal 6, ModelCategory.for("video").table_colspan

    assert ModelCategory.for("language").shows_tier_facet
    refute ModelCategory.for("embeddings").shows_tier_facet
    refute ModelCategory.for("speech-to-text").shows_tier_facet
    refute ModelCategory.for("image").shows_tier_facet
    refute ModelCategory.for("video").shows_tier_facet
  end

  test "the video category is image-shaped: pricing column, non-price sorts, video SEO" do
    video = ModelCategory.for("video")
    assert_equal "name", video.default_sort
    assert_equal "asc", video.default_dir
    assert_equal %w[name provider released], video.sorts
    refute_includes video.sorts, "input"
    refute_includes video.sorts, "native_price"
    assert_match(/video/i, video.title)
    assert_match(/per second/i, video.meta_description)
  end

  test "the speech-to-text category ranks cheapest per-minute first with transcription SEO" do
    speech = ModelCategory.for("speech-to-text")
    assert_equal "native_price", speech.default_sort
    assert_equal "asc", speech.default_dir
    assert_includes speech.sorts, "native_price"
    refute_includes speech.sorts, "input"
    assert_match(/speech-to-text/i, speech.title)
    assert_match(/per minute/i, speech.meta_description)
  end

  test "the embeddings category ranks cheapest input first with token-price SEO" do
    embeddings = ModelCategory.for("embeddings")
    assert_equal "input", embeddings.default_sort
    assert_equal "asc", embeddings.default_dir
    assert_includes embeddings.sorts, "input"
    refute_includes embeddings.sorts, "output"
    assert_match(/embedding/i, embeddings.title)
    assert_match(/input token/i, embeddings.meta_description)
  end

  test "member? accepts a string as well as a symbol" do
    assert ModelCategory.for("image").member?("image_generation")
    assert ModelCategory.for("language").member?("text")
  end

  test "each category exposes sorts, a default sort within them, a direction, and SEO copy" do
    ModelCategory.all.each do |category|
      assert category.sorts.any?, "#{category.slug} should offer at least one sort"
      assert_includes category.sorts, category.default_sort
      assert_includes %w[asc desc], category.default_dir
      assert category.title.present?
      assert category.meta_description.present?
      assert category.param.present?
      assert category.path_name.present?
    end
  end

  test "language sorts allow the token-price keys; image sorts do not" do
    language = ModelCategory.for("language")
    image = ModelCategory.for("image")

    assert_includes language.sorts, "input"
    assert_includes language.sorts, "output"
    assert_equal "output", language.default_sort
    assert_equal "desc", language.default_dir

    refute_includes image.sorts, "input"
    refute_includes image.sorts, "output"
    assert_includes image.sorts, "released"
    assert_equal "name", image.default_sort
    assert_equal "asc", image.default_dir
  end
end
