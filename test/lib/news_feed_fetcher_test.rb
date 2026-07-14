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

  # --- excerpt capture -------------------------------------------------------

  RSS_WITH_CONTENT_ENCODED = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
      <channel>
        <title>AINews</title>
        <link>https://news.smol.ai</link>
        <item>
          <title>OpenAI launches GPT 5.6</title>
          <link>https://news.smol.ai/issues/2026-07-09</link>
          <pubDate>Thu, 09 Jul 2026 05:44:39 GMT</pubDate>
          <description>Short summary mentioning only GPT-5.6.</description>
          <content:encoded><![CDATA[<p>Full roundup. Buried in here: <b>Meta launches Muse Spark 1.1</b>, a new agentic model.</p>]]></content:encoded>
        </item>
      </channel>
    </rss>
  XML

  RSS_WITH_DESCRIPTION_ONLY = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>Latent Space</title>
        <link>https://latent.space</link>
        <item>
          <title>Some post</title>
          <link>https://latent.space/p/some-post</link>
          <pubDate>Thu, 09 Jul 2026 05:44:39 GMT</pubDate>
          <description><![CDATA[<p>A plain description body.</p>]]></description>
        </item>
      </channel>
    </rss>
  XML

  RSS_TITLE_ONLY = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>TLDR AI</title>
        <link>https://tldr.tech/ai</link>
        <item>
          <title>GPT-5.6, Muse Spark 1.1, ChatGPT Work</title>
          <link>https://tldr.tech/ai/2026-07-10</link>
          <pubDate>Fri, 10 Jul 2026 00:00:00 GMT</pubDate>
        </item>
      </channel>
    </rss>
  XML

  test "RSS fetch captures excerpt from content:encoded, stripped of HTML" do
    config = { "name" => "ainews", "type" => "rss", "url" => "https://news.smol.ai/rss.xml" }

    with_stubbed_response(200, RSS_WITH_CONTENT_ENCODED) do
      items = NewsFeedFetcher.fetch(config)

      assert_includes items[0][:excerpt], "Meta launches Muse Spark 1.1"
      assert_not_includes items[0][:excerpt], "<b>"
    end
  end

  test "RSS fetch falls back to description when content:encoded is absent" do
    config = { "name" => "latent_space", "type" => "rss", "url" => "https://latent.space/feed" }

    with_stubbed_response(200, RSS_WITH_DESCRIPTION_ONLY) do
      items = NewsFeedFetcher.fetch(config)

      assert_includes items[0][:excerpt], "A plain description body."
    end
  end

  test "RSS fetch falls back to fetching the item's own link when the feed carries no body" do
    config = { "name" => "tldr_ai", "type" => "rss", "url" => "https://tldr.tech/api/rss/ai" }
    responses = {
      "https://tldr.tech/api/rss/ai" => RSS_TITLE_ONLY,
      "https://tldr.tech/ai/2026-07-10" => "<html><body><p>Full issue text mentioning Muse Spark 1.1 here.</p></body></html>"
    }

    with_stubbed_responses_by_url(responses) do
      items = NewsFeedFetcher.fetch(config)

      assert_includes items[0][:excerpt], "Muse Spark 1.1"
    end
  end

  test "RSS fetch does not fetch the item link when a body is already present" do
    config = { "name" => "ainews", "type" => "rss", "url" => "https://news.smol.ai/rss.xml" }
    fetched_urls = []
    responses = { "https://news.smol.ai/rss.xml" => RSS_WITH_CONTENT_ENCODED }

    with_stubbed_responses_by_url(responses, fetched_urls:) do
      NewsFeedFetcher.fetch(config)
      assert_equal [ "https://news.smol.ai/rss.xml" ], fetched_urls
    end
  end

  test "a failed link fallback fetch leaves excerpt nil instead of dropping the item" do
    config = { "name" => "tldr_ai", "type" => "rss", "url" => "https://tldr.tech/api/rss/ai" }

    with_stubbed_responses_by_url({ "https://tldr.tech/api/rss/ai" => RSS_TITLE_ONLY },
                                   raise_for_others: SocketError.new("getaddrinfo failed")) do
      items = NewsFeedFetcher.fetch(config)

      assert_equal 1, items.size
      assert_nil items[0][:excerpt]
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

  # Build a fake Net::HTTP that returns a different canned body per requested
  # URL, so tests can distinguish the main feed fetch from a per-item link
  # fallback fetch. `responses` is keyed by full URL string. Records every URL
  # requested into `fetched_urls` when given. `raise_for_others` raises that
  # error for any URL not present in `responses` (simulates a broken fallback).
  #
  # NewsFeedFetcher#http_get calls Net::HTTP.start(host, port, **opts, &blk),
  # and inside the block calls http.get(uri.request_uri, headers) — the host
  # is only known at the .start call, the path only at .get, so this stub joins
  # both to recover the full URL each request actually targeted.
  def with_stubbed_responses_by_url(responses, fetched_urls: [], raise_for_others: nil)
    scheme_and_host = nil

    fake = Object.new
    fake.define_singleton_method(:get) do |path, _headers = {}|
      url = "#{scheme_and_host}#{path}"
      fetched_urls << url
      body = responses[url]
      if body.nil?
        raise raise_for_others if raise_for_others
        next Net::HTTPNotFound.new("1.1", "404", "Not Found").tap { |r| r.define_singleton_method(:body) { "" } }
      end
      Net::HTTPOK.new("1.1", "200", "OK").tap { |r| r.define_singleton_method(:body) { body } }
    end

    original_start = Net::HTTP.singleton_class.instance_method(:start)
    Net::HTTP.define_singleton_method(:start) do |host, _port = nil, use_ssl: false, **_kwargs, &blk|
      scheme_and_host = "#{use_ssl ? "https" : "http"}://#{host}"
      blk.call(fake)
    end

    yield
  ensure
    Net::HTTP.singleton_class.define_method(:start, original_start) if original_start
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
