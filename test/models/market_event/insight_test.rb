require "test_helper"

# Ensure Anthropic::Errors::Error exists for error stubs even if the gem
# is not fully loaded in the test environment.
unless defined?(Anthropic::Errors::Error)
  module Anthropic
    module Errors
      class Error < StandardError; end
    end
  end
end

class MarketEvent::InsightTest < ActiveSupport::TestCase
  # A plain stand-in for a MarketEvent responding to the attributes the prompt
  # reads, mirroring the NewsItem::Classification test's stub style.
  def stub_event(title:, event_date:, note: nil, source_url: nil, news_items: [])
    event = Object.new
    event.define_singleton_method(:title)      { title }
    event.define_singleton_method(:event_date) { event_date }
    event.define_singleton_method(:note)       { note }
    event.define_singleton_method(:source_url) { source_url }
    event.define_singleton_method(:news_items) { news_items }
    event
  end

  def stub_news_item(title:, source:, url:)
    item = Object.new
    item.define_singleton_method(:title)  { title }
    item.define_singleton_method(:source) { source }
    item.define_singleton_method(:url)    { url }
    item
  end

  # Fake client whose web-search response yields the given text + citations,
  # and records the prompt it was sent.
  def fake_client(text:, citations: [], into: {})
    block = Object.new
    block.define_singleton_method(:type)      { :text }
    block.define_singleton_method(:text)      { text }
    block.define_singleton_method(:citations) do
      citations.map do |c|
        cite = Object.new
        cite.define_singleton_method(:url)   { c[:url] }
        cite.define_singleton_method(:title) { c[:title] }
        cite
      end
    end
    response = Object.new
    response.define_singleton_method(:content)     { [ block ] }
    response.define_singleton_method(:stop_reason) { :end_turn }

    messages = Object.new
    messages.define_singleton_method(:create) { |**kwargs| into.replace(kwargs); response }
    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  def error_client(error)
    messages = Object.new
    messages.define_singleton_method(:create) { |**_| raise error }
    client = Object.new
    client.define_singleton_method(:messages) { messages }
    client
  end

  test "returns the so_what prose and its citations" do
    event = stub_event(title: "Opus gets 67% cheaper", event_date: Date.new(2025, 11, 24),
                       note: "Anthropic drops Opus pricing to $5/$25.")
    client = fake_client(
      text: "Frontier Opus-tier inference is now a third of its former price, narrowing the gap to mid-tier models.",
      citations: [ { url: "https://anthropic.com/news", title: "Opus 4.5" } ]
    )

    result = MarketEvent::Insight.new(event, client: client).run

    assert_match "third of its former price", result[:so_what]
    assert_equal [ { "url" => "https://anthropic.com/news", "title" => "Opus 4.5" } ], result[:citations]
  end

  test "includes event detail and linked news items in the prompt" do
    sent = {}
    item = stub_news_item(title: "DeepSeek R1 ships", source: "deepseek.com", url: "https://deepseek.com/r1")
    event = stub_event(title: "The DeepSeek moment", event_date: Date.new(2025, 1, 20),
                       note: "Near-frontier reasoning at 1/20th the price.",
                       source_url: "https://example.com/x", news_items: [ item ])
    client = fake_client(text: "x", into: sent)

    MarketEvent::Insight.new(event, client: client).run

    prompt = sent[:messages].first[:content]
    assert_match "The DeepSeek moment", prompt
    assert_match "Near-frontier reasoning", prompt
    assert_match "https://example.com/x", prompt
    assert_match "DeepSeek R1 ships — deepseek.com — https://deepseek.com/r1", prompt
  end

  test "truncates an over-long so_what" do
    event = stub_event(title: "t", event_date: Date.new(2025, 1, 1))
    client = fake_client(text: "A" * 500)

    result = MarketEvent::Insight.new(event, client: client).run

    assert result[:so_what].length <= MarketEvent::Insight::SO_WHAT_LIMIT
  end

  test "caps the number of citations" do
    event = stub_event(title: "t", event_date: Date.new(2025, 1, 1))
    many  = Array.new(10) { |i| { url: "https://example.com/#{i}", title: "S#{i}" } }
    client = fake_client(text: "x", citations: many)

    result = MarketEvent::Insight.new(event, client: client).run

    assert_equal MarketEvent::Insight::MAX_CITATIONS, result[:citations].size
  end

  test "wraps an AnthropicClient error in MarketEvent::Insight::Error" do
    event = stub_event(title: "t", event_date: Date.new(2025, 1, 1))
    client = error_client(Anthropic::Errors::Error.new("overloaded"))

    error = assert_raises(MarketEvent::Insight::Error) do
      MarketEvent::Insight.new(event, client: client).run
    end
    assert_match "overloaded", error.message
  end
end
