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
           url: "https://ai.meta.com/blog/muse-spark", excerpt: nil)
    NewsItem.create!(title:, source:, url:, excerpt:)
  end

  # A fake Anthropic client whose messages.create returns a tool_use block
  # carrying { models: [...] } — mirrors the classification test's stub.
  def fake_client(models)
    tool_block = Object.new
    tool_block.define_singleton_method(:type)  { :tool_use }
    tool_block.define_singleton_method(:input) { { models: models } }
    response = Object.new
    response.define_singleton_method(:content) { [ tool_block ] }
    messages = Object.new
    messages.define_singleton_method(:create) { |**_| response }
    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  def extract(models, news_item = item)
    NewsItem::ModelExtraction.new(news_item, client: fake_client(models)).run
  end

  test "builds a per-token language candidate from a priced launch" do
    candidates = extract([
      { name: "Muse Spark 1.1", provider: "Meta", category: "language",
        confidence: "M", released_on: "2026-07-09",
        pricing: { input: 1.25, output: 4.25, context_window: 256_000 },
        notes: "Meta's first paid model." }
    ])

    assert_equal 1, candidates.size
    candidate = candidates.first
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

  test "returns an empty array when the item announces no model" do
    assert_equal [], extract([])
  end

  test "drops an entry with a blank name rather than raising" do
    assert_equal [], extract([ { name: "", confidence: "L" } ])
  end

  test "a launch with no stated price still yields an identity candidate" do
    candidates = extract([
      { name: "Muse Image", provider: "Meta", category: "image", confidence: "L" }
    ])

    assert_equal 1, candidates.size
    candidate = candidates.first
    assert_not candidate.priced?, "no price stated → unpriced candidate, not a guess"
    assert_equal "L", candidate.confidence
  end

  test "an unknown category is dropped to nil rather than mis-slugged" do
    candidates = extract([
      { name: "Some Robot", provider: "Acme", category: "robotics", confidence: "L" }
    ])
    assert_nil candidates.first.category_slug
  end

  test "falls back to the item's source when no provider is extracted" do
    candidates = extract([ { name: "Mystery Model", confidence: "L" } ])
    assert_equal "meta_ai", candidates.first.provider_name
  end

  test "extracts multiple models bundled in one digest item" do
    candidates = extract([
      { name: "GPT-5.6 Sol", provider: "OpenAI", category: "language", confidence: "H",
        pricing: { input: 1.0, output: 5.0 } },
      { name: "Muse Spark 1.1", provider: "Meta", category: "language", confidence: "M",
        pricing: { input: 1.25, output: 4.25 } }
    ], item(title: "GPT-5.6, Muse Spark 1.1, ChatGPT Work", source: "tldr_ai",
            url: "https://tldr.tech/ai/2026-07-10",
            excerpt: "Full digest mentioning both launches."))

    assert_equal %w[GPT-5.6\ Sol Muse\ Spark\ 1.1], candidates.map(&:name)
    assert_equal %w[OpenAI Meta], candidates.map(&:provider_name)
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

  test "includes the excerpt in the prompt content when present" do
    captured = nil
    messages = Object.new
    messages.define_singleton_method(:create) do |**kwargs|
      captured = kwargs[:messages].first[:content]
      tool_block = Object.new
      tool_block.define_singleton_method(:type)  { :tool_use }
      tool_block.define_singleton_method(:input) { { models: [] } }
      response = Object.new
      response.define_singleton_method(:content) { [ tool_block ] }
      response
    end
    client = Object.new
    client.define_singleton_method(:messages) { messages }

    NewsItem::ModelExtraction.new(
      item(excerpt: "Full text mentioning Muse Spark 1.1 buried in here."), client:
    ).run

    assert_includes captured, "Excerpt:"
    assert_includes captured, "Muse Spark 1.1 buried in here"
  end

  test "NewsItem#extract_model_candidates delegates to the operation" do
    news_item = item
    sentinel = Object.new
    operation = Object.new
    operation.define_singleton_method(:run) { sentinel }

    original = NewsItem::ModelExtraction.method(:new)
    NewsItem::ModelExtraction.define_singleton_method(:new) do |arg, **_|
      arg.equal?(news_item) ? operation : original.call(arg)
    end
    assert_same sentinel, news_item.extract_model_candidates
  ensure
    NewsItem::ModelExtraction.define_singleton_method(:new, original)
  end
end
