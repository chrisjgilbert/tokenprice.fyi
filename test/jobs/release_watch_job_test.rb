require "test_helper"

# The real NewsClassifier is built by a parallel agent; define the minimal
# interface here so these tests don't depend on that file being present.
unless defined?(NewsClassifier)
  class NewsClassifier
    class ClassifyError < StandardError; end
  end
end

class ReleaseWatchJobTest < ActiveJob::TestCase
  FAKE_SOURCES = [
    { "name" => "openai", "type" => "rss", "url" => "https://openai.com/news/rss" }
  ]

  FAKE_ITEMS = [
    { url: "https://openai.com/blog/gpt-5", title: "GPT-5 Released",
      source: "openai", published_at: Time.utc(2026, 6, 1, 10, 0, 0) },
    { url: "https://openai.com/research/new-paper", title: "New Research Paper",
      source: "openai", published_at: Time.utc(2026, 6, 2, 12, 0, 0) }
  ]

  CLASSIFY_RESULT = { relevant: true, kind: "release", rationale: "New model launch" }

  setup do
    # Default stubs — individual tests override as needed
    stub_sources(FAKE_SOURCES)
    stub_fetcher(FAKE_ITEMS)
    stub_classifier(CLASSIFY_RESULT)
  end

  # --- creates records for new items -----------------------------------------

  test "creates NewsItem records for each new feed item" do
    assert_difference "NewsItem.count", 2 do
      ReleaseWatchJob.perform_now
    end
  end

  test "persisted item has correct url, title and source" do
    ReleaseWatchJob.perform_now
    item = NewsItem.find_by!(url: "https://openai.com/blog/gpt-5")
    assert_equal "GPT-5 Released", item.title
    assert_equal "openai", item.source
  end

  # --- duplicate URLs are silently skipped -----------------------------------

  test "duplicate URL (RecordNotUnique) is silently skipped" do
    # Pre-create one of the items so the second attempt hits the unique index.
    NewsItem.create!(url: "https://openai.com/blog/gpt-5",
                     title: "GPT-5 Released", source: "openai")

    assert_difference "NewsItem.count", 1 do
      ReleaseWatchJob.perform_now
    end
  end

  # --- classifier is called for each new item --------------------------------

  test "classifier is called for each new item" do
    classified_urls = []
    stub_classifier_capturing(classified_urls)

    ReleaseWatchJob.perform_now

    assert_equal 2, classified_urls.size
    assert_includes classified_urls, "https://openai.com/blog/gpt-5"
    assert_includes classified_urls, "https://openai.com/research/new-paper"
  end

  test "classification result is persisted to the item" do
    ReleaseWatchJob.perform_now
    item = NewsItem.find_by!(url: "https://openai.com/blog/gpt-5")
    assert_equal true,      item.relevant
    assert_equal "release", item.kind
    assert_equal "New model launch", item.rationale
  end

  test "classifier is NOT called for duplicate (already-existing) items" do
    # Pre-create both items — both will be skipped.
    FAKE_ITEMS.each do |attrs|
      NewsItem.create!(url: attrs[:url], title: attrs[:title], source: attrs[:source])
    end

    classified_urls = []
    stub_classifier_capturing(classified_urls)

    ReleaseWatchJob.perform_now

    assert_empty classified_urls, "classifier should not be called for duplicate items"
  end

  # --- classifier errors leave item unclassified ----------------------------

  test "classifier error leaves item with relevant=nil (unclassified)" do
    stub_classifier_raising(NewsClassifier::ClassifyError, "API rate limit")

    ReleaseWatchJob.perform_now

    item = NewsItem.find_by!(url: "https://openai.com/blog/gpt-5")
    assert_nil item.relevant,  "relevant should stay nil when classifier errors"
    assert_nil item.kind,      "kind should stay nil when classifier errors"
    assert_nil item.rationale, "rationale should stay nil when classifier errors"
  end

  test "classifier error does not prevent other items from being created" do
    stub_classifier_raising(NewsClassifier::ClassifyError, "timeout")

    assert_difference "NewsItem.count", 2 do
      ReleaseWatchJob.perform_now
    end
  end

  private

  def stub_sources(sources)
    original = YAML.method(:safe_load_file)
    YAML.define_singleton_method(:safe_load_file) do |path, **kwargs|
      path.to_s.end_with?("news_sources.yml") ? { "sources" => sources } : original.call(path, **kwargs)
    end
    @yaml_original = original
  end

  def stub_fetcher(items)
    original = NewsFeedFetcher.singleton_class.instance_method(:fetch)
    NewsFeedFetcher.define_singleton_method(:fetch) { |_config| items }
    @fetcher_original = original
  end

  def stub_classifier(result)
    original = NewsClassifier.singleton_class.instance_method(:classify) rescue nil
    NewsClassifier.define_singleton_method(:classify) { |**_kwargs| result }
    @classifier_original = original
  end

  def stub_classifier_capturing(captured_urls)
    NewsClassifier.define_singleton_method(:classify) do |title:, source:|
      # Find the NewsItem that was just created for this title/source
      item = NewsItem.find_by(title: title, source: source)
      captured_urls << item&.url
      { relevant: true, kind: "release", rationale: "captured" }
    end
  end

  def stub_classifier_raising(error_class, message)
    NewsClassifier.define_singleton_method(:classify) { |**_| raise error_class, message }
  end

  teardown do
    if @yaml_original
      YAML.singleton_class.define_method(:safe_load_file, @yaml_original)
    end
    if @fetcher_original
      NewsFeedFetcher.singleton_class.define_method(:fetch, @fetcher_original)
    end
    if @classifier_original
      NewsClassifier.singleton_class.define_method(:classify, @classifier_original)
    elsif NewsClassifier.singleton_class.method_defined?(:classify)
      NewsClassifier.singleton_class.remove_method(:classify)
    end
  end
end
