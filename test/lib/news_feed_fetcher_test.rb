require "test_helper"
require "net/http"

# Same helper defined in client_test.rb and slack_notifier_test.rb — idempotent.
unless Net::HTTP.respond_to?(:stub_new)
  module NetHttpStub
    def stub_new(replacement)
      original = singleton_class.instance_method(:new)
      define_singleton_method(:new) { |*, **| replacement }
      yield
    ensure
      singleton_class.define_method(:new, original)
    end
  end
  Net::HTTP.extend(NetHttpStub)
end

class NewsFeedFetcherTest < ActiveSupport::TestCase
  MINIMAL_RSS = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>OpenAI News</title>
        <link>https://openai.com/news</link>
        <item>
          <title>GPT-5 Released</title>
          <link>https://openai.com/blog/gpt-5</link>
          <pubDate>Mon, 01 Jun 2026 10:00:00 +0000</pubDate>
        </item>
        <item>
          <title>New Research Paper</title>
          <link>https://openai.com/research/new-paper</link>
          <pubDate>Tue, 02 Jun 2026 12:00:00 +0000</pubDate>
        </item>
      </channel>
    </rss>
  XML

  MINIMAL_HTML = <<~HTML
    <html>
      <body>
        <nav><a href="/about">About</a></nav>
        <main>
          <a href="/news/claude-haiku-4-5">Introducing Claude Haiku 4.5 — a new model</a>
          <a href="/news/context-windows">Extended context windows announcement for all tiers</a>
          <a href="https://external.com/story">External story about AI pricing changes</a>
        </main>
      </body>
    </html>
  HTML

  # --- RSS fetch -----------------------------------------------------------

  test "RSS fetch parses items from a minimal RSS 2.0 fixture" do
    config = { "name" => "openai", "type" => "rss", "url" => "https://openai.com/news/rss" }

    with_stubbed_response(200, MINIMAL_RSS) do
      items = NewsFeedFetcher.fetch(config)

      assert_equal 2, items.size

      assert_equal "https://openai.com/blog/gpt-5", items[0][:url]
      assert_equal "GPT-5 Released", items[0][:title]
      assert_equal "openai", items[0][:source]
      assert_not_nil items[0][:published_at]

      assert_equal "https://openai.com/research/new-paper", items[1][:url]
      assert_equal "New Research Paper", items[1][:title]
    end
  end

  test "RSS fetch returns empty array on blank body" do
    config = { "name" => "openai", "type" => "rss", "url" => "https://openai.com/news/rss" }

    with_stubbed_response(200, "") do
      assert_equal [], NewsFeedFetcher.fetch(config)
    end
  end

  test "RSS fetch returns empty array on non-2xx response" do
    config = { "name" => "openai", "type" => "rss", "url" => "https://openai.com/news/rss" }

    with_stubbed_response(500, "Internal Server Error") do
      assert_equal [], NewsFeedFetcher.fetch(config)
    end
  end

  # --- page_diff fetch -----------------------------------------------------

  test "page_diff fetch extracts article links from minimal HTML" do
    config = { "name" => "anthropic", "type" => "page_diff", "url" => "https://www.anthropic.com/news" }

    with_stubbed_response(200, MINIMAL_HTML) do
      items = NewsFeedFetcher.fetch(config)

      urls  = items.map { |i| i[:url] }
      titles = items.map { |i| i[:title] }

      # The two long anchor texts should be included
      assert_includes titles, "Introducing Claude Haiku 4.5 — a new model"
      assert_includes titles, "Extended context windows announcement for all tiers"
      # Short "About" nav link should be filtered out (< 10 chars)
      refute_includes titles, "About"
      # External link should be resolved as-is
      assert_includes urls, "https://external.com/story"
      # Relative links should be resolved against base URL
      assert_includes urls, "https://www.anthropic.com/news/claude-haiku-4-5"
    end
  end

  test "page_diff fetch returns published_at as nil" do
    config = { "name" => "anthropic", "type" => "page_diff", "url" => "https://www.anthropic.com/news" }

    with_stubbed_response(200, MINIMAL_HTML) do
      items = NewsFeedFetcher.fetch(config)
      assert items.all? { |i| i[:published_at].nil? }, "expected all published_at to be nil"
    end
  end

  # --- network error handling ----------------------------------------------

  test "network error (SocketError) returns empty array instead of raising" do
    config = { "name" => "openai", "type" => "rss", "url" => "https://openai.com/news/rss" }

    raising = build_error_http(SocketError, "getaddrinfo failed")
    Net::HTTP.stub_new(raising) do
      assert_equal [], NewsFeedFetcher.fetch(config)
    end
  end

  test "network timeout returns empty array instead of raising" do
    config = { "name" => "openai", "type" => "rss", "url" => "https://openai.com/news/rss" }

    raising = build_error_http(Net::OpenTimeout, "connection timed out")
    Net::HTTP.stub_new(raising) do
      assert_equal [], NewsFeedFetcher.fetch(config)
    end
  end

  test "raises ArgumentError for unknown feed type" do
    config = { "name" => "test", "type" => "unknown", "url" => "https://example.com" }
    assert_raises(ArgumentError) { NewsFeedFetcher.fetch(config) }
  end

  private

  # Build a fake Net::HTTP that returns a canned HTTP response without making
  # real network calls. Uses the Net::HTTP.stub_new pattern.
  def with_stubbed_response(code, body)
    klass = code == 200 ? Net::HTTPOK : Net::HTTPInternalServerError
    response = klass.new("1.1", code.to_s, klass.name)
    response.define_singleton_method(:body) { body }

    fake = Object.new
    fake.define_singleton_method(:use_ssl=) { |_| }
    fake.define_singleton_method(:open_timeout=) { |_| }
    fake.define_singleton_method(:read_timeout=) { |_| }
    fake.define_singleton_method(:start) { |&blk| blk ? blk.call(fake) : fake }
    fake.define_singleton_method(:get) { |_path, _headers = {}| response }

    Net::HTTP.stub_new(fake) { yield }
  end

  # Build a fake that raises the given error class on any method call.
  def build_error_http(error_class, message)
    raising = Object.new
    raising.define_singleton_method(:use_ssl=) { |_| }
    raising.define_singleton_method(:open_timeout=) { |_| }
    raising.define_singleton_method(:read_timeout=) { |_| }
    raising.define_singleton_method(:start) { raise error_class, message }
    raising
  end
end
