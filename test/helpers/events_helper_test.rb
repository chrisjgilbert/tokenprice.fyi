require "test_helper"

class EventsHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "build_all_events surfaces a reprice event for a model whose price moved" do
    reprice = build_all_events.find { |e| e.kind == "reprice" && e.model == ai_models(:deepseek_v4) }

    assert reprice, "expected a reprice event for the model that was repriced"
    assert_equal "DeepSeek V4 Pro repriced", reprice.title
    assert_equal Date.new(2026, 5, 31), reprice.date
    assert_equal price_points(:deepseek_launch), reprice.move.from
    assert_equal price_points(:deepseek_cut), reprice.move.to
    assert_in_delta(-75.0, reprice.move.input, 0.1)
  end

  test "build_all_events emits one reprice event per moved model and none for single-snapshot models" do
    repriced_models = build_all_events.select { |e| e.kind == "reprice" }.map(&:model)

    # Only deepseek_v4 has two snapshots in the fixtures; the rest launch once.
    assert_equal [ ai_models(:deepseek_v4) ], repriced_models
    refute_includes repriced_models, ai_models(:opus)
  end

  test "build_all_events leaves launch and market events with a nil move" do
    non_reprice = build_all_events.reject { |e| e.kind == "reprice" }

    assert non_reprice.any?
    assert non_reprice.all? { |e| e.move.nil? }
  end

  # The sync writes many repricings in one batch, all dated today; the hero must
  # still show a mix, not two price changes in a row.
  test "hero_events picks the newest event then the newest of a different kind" do
    events = [
      build_event(27, "reprice", "Zeta repriced"),
      build_event(27, "reprice", "Alpha repriced"),
      build_event(20, "launch",  "Gamma released"),
      build_event(10, "market",  "A market event")
    ]

    picked = hero_events(events, count: 2)

    assert_equal %w[reprice launch], picked.map(&:kind)
    assert_equal "Zeta repriced", picked.first.title, "primary stays the genuinely newest event"
  end

  test "hero_events falls back to the same kind when no other kind is available" do
    events = [ build_event(27, "reprice", "Zeta repriced"), build_event(26, "reprice", "Alpha repriced") ]

    picked = hero_events(events, count: 2)

    assert_equal %w[reprice reprice], picked.map(&:kind)
    assert_equal 2, picked.size
  end

  private

  def build_event(day, kind, title)
    EventsHelper::Event.new(date: Date.new(2026, 6, day), title: title, kind: kind,
                            note: nil, model: nil, provider: nil, source_url: nil, move: nil)
  end
end
