require "test_helper"

class EventsHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "build_all_events never surfaces a reprice event, even for a model whose price moved" do
    # deepseek_v4 has two snapshots (launch + a 75% cut) in the fixtures — the
    # exact case that used to produce a reprice event. Price changes are no
    # longer surfaced as events; significant ones become curated MarketEvents.
    kinds = build_all_events.map(&:kind)

    refute_includes kinds, "reprice"
    assert_includes build_all_events.select { |e| e.model == ai_models(:deepseek_v4) }.map(&:kind), "launch"
  end

  test "build_all_events carries the so_what and citations onto market events" do
    me = MarketEvent.create!(title: "Opus gets cheaper", event_date: Date.new(2025, 11, 24),
                             kind: "market", status: "published",
                             so_what: "Frontier prices fell a third.",
                             citations: [ { "url" => "https://example.com", "title" => "Src" } ])

    event = build_all_events(market_events: [ me ], models: []).find { |e| e.kind == "market" }

    assert_equal "Frontier prices fell a third.", event.so_what
    assert_equal [ { "url" => "https://example.com", "title" => "Src" } ], event.citations
  end

  test "a priced model's launch note names its per-token rates" do
    launch = build_all_events.find { |e| e.kind == "launch" && e.model == ai_models(:opus) }

    assert launch, "expected the priced model to emit a launch event"
    assert_includes launch.note, "per 1M"
  end

  test "hero_events returns the N most recent events regardless of kind" do
    events = [
      build_event(27, "promo",  "Zeta promo"),
      build_event(26, "promo",  "Alpha promo"),
      build_event(20, "launch", "Gamma released"),
      build_event(10, "market", "A market event")
    ]

    picked = hero_events(events, count: 3)

    assert_equal [ "Zeta promo", "Alpha promo", "Gamma released" ], picked.map(&:title)
  end

  test "hero_events shows more than one event of the same kind — no one-per-kind cap" do
    # Regression: two unrelated same-day launches (e.g. Sonnet 5 and Nano
    # Banana 2 Lite, both 2026-06-30) should both be able to appear rather
    # than the hero having to pick a single "winner" between them.
    events = [
      build_event(30, "launch", "Claude Sonnet 5 released"),
      build_event(30, "launch", "Nano Banana 2 Lite released"),
      build_event(29, "market", "DeepSeek V4 adds peak-valley pricing")
    ]

    picked = hero_events(events, count: 3)

    assert_equal %w[launch launch market], picked.map(&:kind)
  end

  test "hero_events defaults to five events and truncates a longer list" do
    events = (1..10).map { |d| build_event(d, "launch", "Model #{d} released") }

    picked = hero_events(events)

    assert_equal 5, picked.size
    assert_equal "Model 10 released", picked.first.title
  end

  private

  def build_event(day, kind, title, model: nil)
    EventsHelper::Event.new(date: Date.new(2026, 6, day), title: title, kind: kind,
                            note: nil, model: model, provider: nil, source_url: nil,
                            so_what: nil, citations: [])
  end
end
