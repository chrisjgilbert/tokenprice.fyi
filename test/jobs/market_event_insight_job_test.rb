require "test_helper"

unless defined?(Anthropic::Errors::Error)
  module Anthropic
    module Errors
      class Error < StandardError; end
    end
  end
end

class MarketEventInsightJobTest < ActiveJob::TestCase
  def event
    @event ||= MarketEvent.create!(title: "Opus gets 67% cheaper", event_date: Date.new(2025, 11, 24),
                                   kind: "market", status: "published", note: "Opus drops to $5/$25.")
  end

  # Stub Anthropic::Client.new globally so generate_insight (which builds its own
  # client) gets our fake web-search response.
  def stub_anthropic(text: "x", citations: [], raises: nil)
    stub_anthropic_key!
    block = Object.new
    block.define_singleton_method(:type) { :text }
    block.define_singleton_method(:text) { text }
    block.define_singleton_method(:citations) do
      citations.map { |c| Struct.new(:url, :title).new(c[:url], c[:title]) }
    end
    response = Object.new
    response.define_singleton_method(:content)     { [ block ] }
    response.define_singleton_method(:stop_reason) { :end_turn }
    messages = Object.new
    messages.define_singleton_method(:create) { |**_| raises ? (raise raises) : response }
    fake = Object.new
    fake.define_singleton_method(:messages) { messages }
    Anthropic::Client.define_singleton_method(:new) { |**_| fake }
  end

  teardown do
    if Anthropic::Client.singleton_class.instance_methods(false).include?(:new)
      Anthropic::Client.singleton_class.remove_method(:new)
    end
  end

  test "generates and persists the insight for the event" do
    stub_anthropic(text: "Frontier Opus pricing fell to a third.",
                   citations: [ { url: "https://anthropic.com/news", title: "Opus 4.5" } ])

    MarketEventInsightJob.perform_now(event)
    event.reload

    assert_equal "Frontier Opus pricing fell to a third.", event.so_what
    assert_equal [ { "url" => "https://anthropic.com/news", "title" => "Opus 4.5" } ], event.citations
  end

  test "swallows an insight error without raising or persisting" do
    stub_anthropic(raises: Anthropic::Errors::Error.new("overloaded"))

    assert_nothing_raised { MarketEventInsightJob.perform_now(event) }
    assert_nil event.reload.so_what
  end
end
