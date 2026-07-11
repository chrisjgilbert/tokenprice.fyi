require "test_helper"

class PricingStalenessTest < ActiveSupport::TestCase
  # A fixed "today" so ages are deterministic regardless of when the suite runs.
  TODAY = Date.new(2026, 10, 1)

  def report(days: 90, today: TODAY)
    PricingStaleness.new(days:, today:).report
  end

  def row_for(slug, **opts)
    report(**opts).flat_map(&:rows).find { |r| r.slug == slug }
  end

  test "reports only curated (manual-source) rows, never OpenRouter-synced ones" do
    slugs = report.flat_map(&:rows).map(&:slug)

    assert_includes slugs, "test-priced-image-model" # manual directory row
    assert_not_includes slugs, "test-image-model"     # openrouter-sourced, excluded
    assert_not_includes slugs, "test-embedding-model" # openrouter-sourced, excluded
  end

  test "groups rows under their ModelCategory, in registry order" do
    labels = report.map { |g| g.category.label }

    assert_equal labels, labels.uniq
    assert_equal labels, ModelCategory.all.map(&:label) & labels # a subsequence, in order
    image = report.find { |g| g.category.slug == "image" }
    assert_includes image.rows.map(&:slug), "test-priced-image-model"
  end

  test "a directory row past the threshold is flagged stale with its age" do
    # test-priced-image-model is priced_as_of 2026-07-01; 92 days before TODAY.
    row = row_for("test-priced-image-model", days: 90)

    assert row.stale?
    assert row.flagged?
    assert_equal 92, row.age_days
    assert_equal Date.new(2026, 7, 1), row.priced_on
  end

  test "the same row is fresh under a longer threshold" do
    row = row_for("test-priced-image-model", days: 120)

    assert_not row.stale?
    assert_equal :fresh, row.status
    assert_not row.flagged?
  end

  test "a native-priced row with no priced_as_of is flagged undated, not unpriced" do
    # The stt fixture carries native_price_usd but no priced_as_of, so its age
    # can't be computed — a distinct maintenance signal from 'unpriced'.
    row = row_for("test-transcribe")

    assert row.undated?
    assert row.flagged?
    assert_nil row.priced_on
    assert_nil row.age_days
  end

  test "a curated directory row awaiting any price is flagged unpriced" do
    provider = Provider.create!(name: "Synth Labs", slug: "synth-labs", accent: "#123456")
    provider.ai_models.create!(name: "Unpriced Synth", tier: "mid", status: "active",
                               source: AiModel::MANUAL_SOURCE,
                               input_modalities: %w[text], output_modalities: %w[audio])

    row = row_for("unpriced-synth")
    assert row.unpriced?
    assert row.flagged?
    assert_nil row.priced_on
  end

  test "rows sort oldest-price-first within a category, unpriced and undated leading" do
    provider = Provider.create!(name: "Aud Labs", slug: "aud-labs", accent: "#222222")
    # A dated TTS row so the text-to-speech group has both an undated (fixture)
    # and a dated member to order.
    dated = provider.ai_models.create!(name: "Dated Voice", tier: "mid", status: "active",
                                       source: AiModel::MANUAL_SOURCE,
                                       input_modalities: %w[text], output_modalities: %w[audio],
                                       native_price_usd: 20, native_price_unit: "/1M chars",
                                       priced_as_of: Date.new(2026, 8, 1))

    tts = report.find { |g| g.category.slug == "text-to-speech" }
    statuses = tts.rows.map(&:status)
    # The undated fixture row sorts ahead of the dated one.
    assert_operator statuses.index(:undated), :<, statuses.index(:fresh)
    assert_includes tts.rows.map(&:slug), dated.slug
  end

  test "totals sum the flagged rows across categories" do
    totals = PricingStaleness.new(days: 90, today: TODAY).totals

    assert_equal totals[:curated], report.flat_map(&:rows).size
    assert_operator totals[:undated], :>=, 1 # the stt/tts fixtures
    assert_equal totals[:stale], report.flat_map(&:rows).count(&:stale?)
  end
end
