require "test_helper"

class NewsScanJobTest < ActiveJob::TestCase
  QUERY_TERMS = %w[Anthropic OpenAI]

  FAKE_ITEMS = [
    { url: "https://techcrunch.com/claude4",   title: "Claude 4 launches",   source: "hn", published_at: Time.utc(2026, 6, 1, 10, 0, 0) },
    { url: "https://techcrunch.com/openai-o3", title: "OpenAI o3 available", source: "hn", published_at: Time.utc(2026, 6, 1, 11, 0, 0) }
  ]

  CLASSIFY_RESULT = { relevant: true, kind: "release", rationale: "New model" }

  setup do
    Rails.cache.delete(NewsScanJob::CACHE_KEY)
    stub_providers(QUERY_TERMS)
    stub_fetcher { |_term, _call_count| FAKE_ITEMS }
    stub_classifier(CLASSIFY_RESULT)
  end

  teardown do
    Rails.cache.delete(NewsScanJob::CACHE_KEY)
    if Provider.singleton_class.instance_methods(false).include?(:pluck)
      Provider.singleton_class.remove_method(:pluck)
    end
    if @fetcher_original
      HnAlgoliaFetcher.singleton_class.define_method(:fetch, @fetcher_original)
    elsif HnAlgoliaFetcher.singleton_class.instance_methods(false).include?(:fetch)
      HnAlgoliaFetcher.singleton_class.remove_method(:fetch)
    end
    if @classifier_original
      NewsClassifier.singleton_class.define_method(:classify, @classifier_original)
    elsif NewsClassifier.singleton_class.instance_methods(false).include?(:classify)
      NewsClassifier.singleton_class.remove_method(:classify)
    end
  end

  # --- record creation -------------------------------------------------------

  test "creates a NewsItem for each unique URL" do
    assert_difference "NewsItem.count", 2 do
      NewsScanJob.perform_now
    end
  end

  test "persists correct url, title and source" do
    NewsScanJob.perform_now
    item = NewsItem.find_by!(url: "https://techcrunch.com/claude4")
    assert_equal "Claude 4 launches", item.title
    assert_equal "hn", item.source
  end

  # --- deduplication ---------------------------------------------------------

  test "same URL returned by multiple query terms is stored only once" do
    shared = { url: "https://techcrunch.com/shared", title: "AI story", source: "hn", published_at: nil }
    stub_fetcher { |_term, _n| [ shared ] }

    assert_difference "NewsItem.count", 1 do
      NewsScanJob.perform_now
    end
  end

  test "already-persisted URL is silently skipped" do
    NewsItem.create!(url: "https://techcrunch.com/claude4", title: "existing", source: "hn")
    assert_difference "NewsItem.count", 1 do
      NewsScanJob.perform_now
    end
  end

  # --- cache -----------------------------------------------------------------

  test "writes current time as integer epoch to cache after successful run" do
    with_memory_cache do
      freeze_time do
        NewsScanJob.perform_now
        assert_equal Time.current.to_i, Rails.cache.read(NewsScanJob::CACHE_KEY)
      end
    end
  end

  test "passes cached last_run_at as since floor" do
    with_memory_cache do
      last_run_i = 12.hours.ago.to_i
      Rails.cache.write(NewsScanJob::CACHE_KEY, last_run_i)

      captured_since = nil
      HnAlgoliaFetcher.define_singleton_method(:fetch) { |query:, since:, **| captured_since = since; [] }

      NewsScanJob.perform_now
      assert_equal last_run_i, captured_since
    end
  end

  test "defaults since to 24 hours ago integer epoch when cache is empty" do
    captured_since = nil
    HnAlgoliaFetcher.define_singleton_method(:fetch) { |query:, since:, **| captured_since = since; [] }

    freeze_time do
      NewsScanJob.perform_now
      assert_equal 24.hours.ago.to_i, captured_since
    end
  end

  test "does not write cache and creates no records when no providers exist" do
    stub_providers([])
    with_memory_cache do
      assert_no_difference "NewsItem.count" do
        NewsScanJob.perform_now
      end
      assert_nil Rails.cache.read(NewsScanJob::CACHE_KEY), "cache should not be written when providers list is empty"
    end
  end

  test "passes MIN_POINTS to the fetcher" do
    captured_min_points = nil
    HnAlgoliaFetcher.define_singleton_method(:fetch) { |query:, since:, min_points:, **| captured_min_points = min_points; [] }

    NewsScanJob.perform_now
    assert_equal NewsScanJob::MIN_POINTS, captured_min_points
  end

  # --- classifier ------------------------------------------------------------

  test "classifier result is persisted to each new item" do
    NewsScanJob.perform_now
    item = NewsItem.find_by!(url: "https://techcrunch.com/claude4")
    assert_equal true,      item.relevant
    assert_equal "release", item.kind
    assert_equal "New model", item.rationale
  end

  test "classifier error leaves item unclassified but does not prevent other items" do
    stub_classifier_raising(NewsClassifier::ClassifyError, "API error")

    assert_difference "NewsItem.count", 2 do
      NewsScanJob.perform_now
    end
    assert_nil NewsItem.find_by!(url: "https://techcrunch.com/claude4").relevant
  end

  private

  def stub_providers(names)
    Provider.define_singleton_method(:pluck) { |*| names }
  end

  def stub_fetcher(&block)
    @fetcher_original ||= (HnAlgoliaFetcher.singleton_class.instance_method(:fetch) rescue nil)
    call_number = 0
    HnAlgoliaFetcher.define_singleton_method(:fetch) do |query:, **|
      call_number += 1
      block.call(query, call_number)
    end
  end

  def stub_classifier(result)
    @classifier_original = NewsClassifier.singleton_class.instance_method(:classify) rescue nil
    NewsClassifier.define_singleton_method(:classify) { |**| result }
  end

  def stub_classifier_raising(error_class, message)
    NewsClassifier.define_singleton_method(:classify) { |**| raise error_class, message }
  end

  def with_memory_cache
    old = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = old
  end
end
