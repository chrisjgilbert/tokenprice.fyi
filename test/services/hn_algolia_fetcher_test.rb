require "test_helper"
require "net/http"

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

class HnAlgoliaFetcherTest < ActiveSupport::TestCase
  SAMPLE_HITS = {
    "hits" => [
      {
        "objectID"     => "12345",
        "title"        => "Anthropic Releases Claude 4",
        "url"          => "https://techcrunch.com/2026/06/01/claude4",
        "points"       => 350,
        "num_comments" => 120,
        "created_at_i" => 1748736000
      },
      {
        "objectID"     => "67890",
        "title"        => "Ask HN: Thoughts on the new Claude?",
        "url"          => nil,
        "points"       => 80,
        "num_comments" => 60,
        "created_at_i" => 1748736000
      }
    ]
  }.to_json

  # --- normal fetch ----------------------------------------------------------

  test "returns array of items with url, title, source, published_at" do
    with_response(200, SAMPLE_HITS) do
      items = HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
      assert_equal 2, items.size
      assert items.all? { |i| i.key?(:url) && i.key?(:title) && i.key?(:source) && i.key?(:published_at) }
    end
  end

  test "uses article url when present" do
    with_response(200, SAMPLE_HITS) do
      items = HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
      assert_equal "https://techcrunch.com/2026/06/01/claude4", items[0][:url]
    end
  end

  test "falls back to HN permalink when url is nil" do
    with_response(200, SAMPLE_HITS) do
      items = HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
      assert_equal "https://news.ycombinator.com/item?id=67890", items[1][:url]
    end
  end

  test "source is always 'hn'" do
    with_response(200, SAMPLE_HITS) do
      items = HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
      assert items.all? { |i| i[:source] == "hn" }, "expected all items to have source 'hn'"
    end
  end

  test "published_at is a UTC Time derived from created_at_i" do
    with_response(200, SAMPLE_HITS) do
      items = HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
      assert_instance_of Time, items[0][:published_at]
      assert_equal "UTC", items[0][:published_at].zone
      assert_equal Time.at(1748736000).utc, items[0][:published_at]
    end
  end

  test "returns empty array when hits is empty" do
    with_response(200, '{"hits":[]}') do
      assert_equal [], HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
    end
  end

  test "request path contains numericFilters with since epoch and min_points" do
    captured_path = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { '{"hits":[]}' }

    fake = Object.new
    fake.define_singleton_method(:use_ssl=)      { |_| }
    fake.define_singleton_method(:open_timeout=) { |_| }
    fake.define_singleton_method(:read_timeout=) { |_| }
    fake.define_singleton_method(:start) { |&blk| blk ? blk.call(fake) : fake }
    fake.define_singleton_method(:get)   { |path, _hdrs = {}| captured_path = path; response }

    since_i = Time.utc(2026, 1, 1).to_i
    Net::HTTP.stub_new(fake) do
      HnAlgoliaFetcher.fetch(query: "anthropic", since: since_i, min_points: 25)
    end

    assert_not_nil captured_path
    # URI.parse encodes > as %3E — verify both the param name and the integer values survive
    assert_match(/numericFilters=points%3E25,created_at_i%3E#{since_i}/, captured_path,
                 "expected numericFilters with %3E-encoded > signs and correct integer values")
  end

  test "skips hits with blank title" do
    body = { "hits" => [ { "objectID" => "1", "title" => "  ", "url" => "https://example.com", "created_at_i" => 1748736000 } ] }.to_json
    with_response(200, body) do
      assert_equal [], HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
    end
  end

  test "skips hit with nil created_at_i without raising" do
    body = {
      "hits" => [
        { "objectID" => "1", "title" => "Has timestamp",   "url" => "https://example.com/a", "created_at_i" => 1748736000 },
        { "objectID" => "2", "title" => "Missing timestamp", "url" => "https://example.com/b", "created_at_i" => nil }
      ]
    }.to_json
    with_response(200, body) do
      items = HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
      assert_equal 1, items.size
      assert_equal "https://example.com/a", items[0][:url]
    end
  end

  test "skips hit when both url and objectID are nil" do
    body = { "hits" => [ { "objectID" => nil, "title" => "No url or id", "url" => nil, "created_at_i" => 1748736000 } ] }.to_json
    with_response(200, body) do
      assert_equal [], HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
    end
  end

  # --- error handling --------------------------------------------------------

  test "returns empty array on non-2xx response" do
    with_response(500, "Internal Server Error") do
      assert_equal [], HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
    end
  end

  test "returns empty array on malformed JSON" do
    with_response(200, "not json at all") do
      assert_equal [], HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
    end
  end

  test "returns empty array on network timeout" do
    raising = build_error_http(Net::OpenTimeout, "connection timed out")
    Net::HTTP.stub_new(raising) do
      assert_equal [], HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
    end
  end

  test "returns empty array on SocketError" do
    raising = build_error_http(SocketError, "getaddrinfo failed")
    Net::HTTP.stub_new(raising) do
      assert_equal [], HnAlgoliaFetcher.fetch(query: "anthropic", since: 24.hours.ago)
    end
  end

  private

  def with_response(code, body)
    klass    = code == 200 ? Net::HTTPOK : Net::HTTPInternalServerError
    response = klass.new("1.1", code.to_s, klass.name)
    response.define_singleton_method(:body) { body }

    fake = Object.new
    fake.define_singleton_method(:use_ssl=)      { |_| }
    fake.define_singleton_method(:open_timeout=) { |_| }
    fake.define_singleton_method(:read_timeout=) { |_| }
    fake.define_singleton_method(:start) { |&blk| blk ? blk.call(fake) : fake }
    fake.define_singleton_method(:get)   { |_path, _hdrs = {}| response }

    Net::HTTP.stub_new(fake) { yield }
  end

  def build_error_http(error_class, message)
    obj = Object.new
    obj.define_singleton_method(:use_ssl=)      { |_| }
    obj.define_singleton_method(:open_timeout=) { |_| }
    obj.define_singleton_method(:read_timeout=) { |_| }
    obj.define_singleton_method(:start) { raise error_class, message }
    obj
  end
end
