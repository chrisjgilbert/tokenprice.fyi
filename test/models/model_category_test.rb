require "test_helper"

class ModelCategoryTest < ActiveSupport::TestCase
  test "for resolves the known params" do
    assert_equal "language", ModelCategory.for("language").slug
    assert_equal "embeddings", ModelCategory.for("embeddings").slug
    assert_equal "rerank", ModelCategory.for("rerank").slug
    assert_equal "speech-to-text", ModelCategory.for("speech-to-text").slug
    assert_equal "text-to-speech", ModelCategory.for("text-to-speech").slug
    assert_equal "image", ModelCategory.for("image").slug
    assert_equal "video", ModelCategory.for("video").slug
  end

  test "for falls back to the language default for nil, blank, or unknown params" do
    assert_equal ModelCategory.default, ModelCategory.for(nil)
    assert_equal ModelCategory.default, ModelCategory.for("")
    assert_equal ModelCategory.default, ModelCategory.for("nonsense")
    assert_equal "language", ModelCategory.default.slug
  end

  test "all is the ordered tab strip: language, the retrieval pair, then the audio and visual pairs" do
    assert_equal %w[language embeddings rerank speech-to-text text-to-speech image video], ModelCategory.all.map(&:slug)
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

    tts = ModelCategory.for("text-to-speech")
    assert tts.member?(:text_to_speech)
    refute tts.member?(:speech_to_text)
    refute tts.member?(:text)
    refute language.member?(:text_to_speech)

    rerank = ModelCategory.for("rerank")
    assert rerank.member?(:rerank)
    refute rerank.member?(:embedding)
    refute rerank.member?(:text)
    refute language.member?(:rerank)

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
    refute ModelCategory.unclaimed?(:text_to_speech)
    refute ModelCategory.unclaimed?(:video_generation)
    refute ModelCategory.unclaimed?(:rerank)
  end

  test "columns and table_colspan describe each category's table shape" do
    assert_equal %i[name input output cached context released], ModelCategory.for("language").columns
    assert_equal %i[name provider input dimensions context released], ModelCategory.for("embeddings").columns
    assert_equal %i[name provider pricing released], ModelCategory.for("rerank").columns
    assert_equal %i[name provider native_price released], ModelCategory.for("speech-to-text").columns
    assert_equal %i[name provider native_price released], ModelCategory.for("text-to-speech").columns
    assert_equal %i[name provider pricing released], ModelCategory.for("image").columns
    assert_equal %i[name provider pricing released], ModelCategory.for("video").columns

    # colspan = columns + the leading select and trailing go columns.
    assert_equal 8, ModelCategory.for("language").table_colspan
    assert_equal 8, ModelCategory.for("embeddings").table_colspan
    assert_equal 6, ModelCategory.for("rerank").table_colspan
    assert_equal 6, ModelCategory.for("speech-to-text").table_colspan
    assert_equal 6, ModelCategory.for("text-to-speech").table_colspan
    assert_equal 6, ModelCategory.for("image").table_colspan
    assert_equal 6, ModelCategory.for("video").table_colspan
  end

  test "the text-to-speech category ranks cheapest per-1M-char first with synthesis SEO" do
    tts = ModelCategory.for("text-to-speech")
    assert_equal "native_price", tts.default_sort
    assert_equal "asc", tts.default_dir
    assert_includes tts.sorts, "native_price"
    assert_match(/text-to-speech/i, tts.title)
    assert_match(/per 1M characters/i, tts.meta_description)
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

  test "every category carries hero copy" do
    ModelCategory.all.each do |c|
      assert c.hero_eyebrow.present?, "#{c.slug} should have a hero eyebrow"
      assert c.hero_heading.present?, "#{c.slug} should have a hero heading"
      assert c.hero_subhead.present?, "#{c.slug} should have a hero subhead"
    end
  end

  test "language hero leads the price index; directory categories signal dated list prices" do
    language = ModelCategory.for("language")
    assert_match(/price index/i, language.hero_eyebrow)
    assert_match(/tracked from launch/i, language.hero_heading)

    %w[embeddings rerank speech-to-text text-to-speech image video].each do |slug|
      eyebrow = ModelCategory.for(slug).hero_eyebrow
      assert_match(/director|dated/i, eyebrow, "#{slug} eyebrow should signal the directory tier")
    end
  end

  test "directory hero headings name their native billing unit, not tokens" do
    assert_match(/image/i, ModelCategory.for("image").hero_heading)
    assert_match(/per minute/i, ModelCategory.for("speech-to-text").hero_heading)
    assert_match(/character/i, ModelCategory.for("text-to-speech").hero_heading)
    assert_no_match(/per 1M tokens/i, ModelCategory.for("image").hero_subhead)
  end

  test "hero subhead is a format string filled from model and provider counts" do
    filled = ModelCategory.for("image").hero_subhead % { models: 22, providers: 9 }
    assert_match(/22/, filled)
    assert_no_match(/%\{/, filled)

    filled_lang = ModelCategory.for("language").hero_subhead % { models: 63, providers: 12 }
    assert_match(/63/, filled_lang)
    assert_match(/12/, filled_lang)
  end

  test "only language is language?" do
    assert ModelCategory.for("language").language?
    refute ModelCategory.for("image").language?
    refute ModelCategory.for("embeddings").language?
  end

  test "claiming returns the category that owns a modality class" do
    assert_equal "image", ModelCategory.claiming(:image_generation).slug
    assert_equal "speech-to-text", ModelCategory.claiming(:speech_to_text).slug
    assert_equal "video", ModelCategory.claiming(:video_generation).slug
    assert_equal "embeddings", ModelCategory.claiming(:embedding).slug
    assert_equal "rerank", ModelCategory.claiming(:rerank).slug
    # Anything no directory category claims is language.
    assert_equal "language", ModelCategory.claiming(:text).slug
    assert_equal "language", ModelCategory.claiming(:multimodal).slug
    assert_equal "language", ModelCategory.claiming(:any_to_any).slug
  end

  test "every category names its native billing unit" do
    assert_equal "per image", ModelCategory.for("image").billing_noun
    assert_match(/per minute/, ModelCategory.for("speech-to-text").billing_noun)
    assert_match(/character/, ModelCategory.for("text-to-speech").billing_noun)
    assert_match(/second|clip/, ModelCategory.for("video").billing_noun)
    ModelCategory.all.each { |c| assert c.billing_noun.present?, "#{c.slug} should name a billing unit" }
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

  test "language also sorts by released, alongside every other category" do
    ModelCategory.all.each do |category|
      assert_includes category.sorts, "released", "#{category.slug} should offer a released sort"
      assert_includes category.columns, :released, "#{category.slug} should render a Released column"
    end
  end
end
