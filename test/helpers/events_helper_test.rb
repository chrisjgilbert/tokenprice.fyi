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

  # Several events can land on the same day (e.g. a batch of curated market
  # events); the hero must still show a mix, not two of the same kind in a row.
  test "hero_events picks the newest event then the newest of a different kind" do
    events = [
      build_event(27, "promo",  "Zeta promo"),
      build_event(27, "promo",  "Alpha promo"),
      build_event(20, "launch", "Gamma released"),
      build_event(10, "market", "A market event")
    ]

    picked = hero_events(events, count: 2)

    assert_equal %w[promo launch], picked.map(&:kind)
    assert_equal "Zeta promo", picked.first.title, "primary stays the genuinely newest event"
  end

  test "hero_events falls back to the same kind when no other kind is available" do
    events = [ build_event(27, "promo", "Zeta promo"), build_event(26, "promo", "Alpha promo") ]

    picked = hero_events(events, count: 2)

    assert_equal %w[promo promo], picked.map(&:kind)
    assert_equal 2, picked.size
  end

  test "hero_events prefers a same-day frontier launch over a same-day mid-tier one" do
    frontier_launch = build_event(20, "launch", "Frontier model released", model: ai_models(:opus))
    mid_launch      = build_event(20, "launch", "Mid model released", model: ai_models(:sonnet))

    picked = hero_events([ frontier_launch, mid_launch ], count: 2)

    assert_equal "Frontier model released", picked.first.title
  end

  test "hero_events still prefers a newer mid-tier launch over an older frontier one" do
    older_frontier_launch = build_event(9, "launch", "Frontier model released", model: ai_models(:opus))
    newer_mid_launch      = build_event(27, "launch", "Mid model released", model: ai_models(:sonnet))

    picked = hero_events([ older_frontier_launch, newer_mid_launch ], count: 2)

    assert_equal "Mid model released", picked.first.title, "recency must win over tier across different dates"
  end

  private

  def build_event(day, kind, title, model: nil)
    EventsHelper::Event.new(date: Date.new(2026, 6, day), title: title, kind: kind,
                            note: nil, model: model, provider: nil, source_url: nil,
                            so_what: nil, citations: [])
  end
end
