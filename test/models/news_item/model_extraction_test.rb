require "test_helper"

unless defined?(Anthropic::Errors::Error)
  module Anthropic
    module Errors
      class Error < StandardError; end
    end
  end
end

class NewsItem::ModelExtractionTest < ActiveSupport::TestCase
  def item(title: "Meta launches Muse Spark 1.1", source: "meta_ai",
           url: "https://ai.meta.com/blog/muse-spark")
    NewsItem.create!(title:, source:, url:)
  end

  # A fake Anthropic client whose messages.create returns a tool_use block
  # carrying `input_hash` — mirrors the classification test's stub.
  def fake_client(input_hash)
    tool_block = Object.new
    tool_block.define_singleton_method(:type)  { :tool_use }
    tool_block.define_singleton_method(:input) { input_hash }
    response = Object.new
    response.define_singleton_method(:content) { [ tool_block ] }
    messages = Object.new
    messages.define_singleton_method(:create) { |**_| response }
    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  def extract(input_hash, news_item = item)
    NewsItem::ModelExtraction.new(news_item, client: fake_client(input_hash)).run
  end

  test "builds a per-token language candidate from a priced launch" do
    candidate = extract(
      is_new_model: true, name: "Muse Spark 1.1", provider: "Meta", category: "language",
      confidence: "M", released_on: "2026-07-09",
      pricing: { input: 1.25, output: 4.25, context_window: 256_000 },
      notes: "Meta's first paid model."
    )

    assert_instance_of ModelCandidate, candidate
    assert_equal "Muse Spark 1.1", candidate.name
    assert_equal "Meta", candidate.provider_name
    assert_equal "language", candidate.category_slug
    assert_equal "M", candidate.confidence
    assert_equal Date.new(2026, 7, 9), candidate.released_on
    assert_equal 1.25, candidate.pricing_hash[:input]
    assert_equal "https://ai.meta.com/blog/muse-spark", candidate.source_url
    assert candidate.priced?
  end

  test "returns nil when the item does not announce a new model" do
    assert_nil extract(is_new_model: false, confidence: "L")
  end

  test "returns nil when is_new_model is true but no name was extracted" do
    assert_nil extract(is_new_model: true, name: "", confidence: "L")
  end

  test "a launch with no stated price still yields an identity candidate" do
    candidate = extract(is_new_model: true, name: "Muse Image", provider: "Meta",
                        category: "image", confidence: "L")

    assert_instance_of ModelCandidate, candidate
    assert_not candidate.priced?, "no price stated → unpriced candidate, not a guess"
    assert_equal "L", candidate.confidence
  end

  test "an unknown category is dropped to nil rather than mis-slugged" do
    candidate = extract(is_new_model: true, name: "Some Robot", provider: "Acme",
                        category: "robotics", confidence: "L")
    assert_nil candidate.category_slug
  end

  test "falls back to the item's source when no provider is extracted" do
    candidate = extract(is_new_model: true, name: "Mystery Model", confidence: "L")
    assert_equal "meta_ai", candidate.provider_name
  end

  test "wraps an Anthropic transport error in a domain error" do
    messages = Object.new
    messages.define_singleton_method(:create) { |**_| raise Anthropic::Errors::Error, "boom" }
    client = Object.new
    client.define_singleton_method(:messages) { messages }

    assert_raises(NewsItem::ModelExtraction::Error) do
      NewsItem::ModelExtraction.new(item, client:).run
    end
  end

  test "NewsItem#extract_model_candidate delegates to the operation" do
    news_item = item
    sentinel = Object.new
    operation = Object.new
    operation.define_singleton_method(:run) { sentinel }

    original = NewsItem::ModelExtraction.method(:new)
    NewsItem::ModelExtraction.define_singleton_method(:new) do |arg, **_|
      arg.equal?(news_item) ? operation : original.call(arg)
    end
    assert_same sentinel, news_item.extract_model_candidate
  ensure
    NewsItem::ModelExtraction.define_singleton_method(:new, original)
  end
end
