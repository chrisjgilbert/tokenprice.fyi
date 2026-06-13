require "test_helper"

module OpenRouter
  class SyncDigestTest < ActiveSupport::TestCase
    def make_repriced(overrides = {})
      ModelSync::RepricedRecord.new(
        model_name:         overrides.fetch(:model_name,  "Claude Opus 4.8"),
        provider_name:      overrides.fetch(:provider_name, "Anthropic"),
        model_slug:         overrides.fetch(:model_slug,  "anthropic-claude-opus-4-8"),
        old_input:          overrides.fetch(:old_input,   15.0),
        old_output:         overrides.fetch(:old_output,  75.0),
        old_cached:         overrides.fetch(:old_cached,  nil),
        new_input:          overrides.fetch(:new_input,   12.0),
        new_output:         overrides.fetch(:new_output,  60.0),
        new_cached:         overrides.fetch(:new_cached,  nil),
        pct_blended_change: overrides.fetch(:pct_blended_change, -20.0)
      )
    end

    def make_created(overrides = {})
      ModelSync::CreatedRecord.new(
        model_name:     overrides.fetch(:model_name,     "Wonder 1"),
        provider_name:  overrides.fetch(:provider_name,  "NewLab"),
        model_slug:     overrides.fetch(:model_slug,     "newlab-wonder-1"),
        new_provider:   overrides.fetch(:new_provider,   false),
        input_per_mtok: overrides.fetch(:input_per_mtok, 0.1),
        output_per_mtok: overrides.fetch(:output_per_mtok, 0.4)
      )
    end

    def make_result(created_records: [], repriced_records: [])
      ModelSync::Result.new(
        created:          created_records.size,
        enriched:         0,
        repriced:         repriced_records.size,
        skipped:          0,
        created_records:  created_records,
        repriced_records: repriced_records
      )
    end

    def digest(result, date: Date.new(2026, 6, 12))
      SyncDigest.new(result, date: date)
    end

    # --- nil when nothing changed -------------------------------------------

    test "returns nil when both records arrays are empty" do
      result = make_result
      assert_nil digest(result).to_slack_payload
    end

    # --- price moves section -------------------------------------------------

    test "includes price moves section when repriced_records are present" do
      result = make_result(repriced_records: [ make_repriced ])
      payload = digest(result).to_slack_payload
      refute_nil payload
      blocks = payload[:blocks]
      assert blocks.any? { |b| b.dig(:text, :text)&.include?("Price moves") }
    end

    test "price moves line contains model name, provider and edit link" do
      r = make_repriced(model_name: "Claude Opus 4.8", provider_name: "Anthropic",
                        model_slug: "anthropic-claude-opus-4-8",
                        old_input: 15.0, old_output: 75.0,
                        new_input: 12.0, new_output: 60.0,
                        pct_blended_change: -20.0)
      payload = digest(make_result(repriced_records: [ r ])).to_slack_payload
      section_text = payload[:blocks].find { |b| b[:type] == "section" }&.dig(:text, :text)
      assert_includes section_text, "Claude Opus 4.8"
      assert_includes section_text, "Anthropic"
      assert_includes section_text, "-20.0%"
      assert_includes section_text, "edit"
      assert_includes section_text, "/admin/models/anthropic-claude-opus-4-8/edit"
    end

    test "shows positive sign for price increase" do
      r = make_repriced(pct_blended_change: 10.0)
      payload = digest(make_result(repriced_records: [ r ])).to_slack_payload
      section_text = payload[:blocks].find { |b| b[:type] == "section" }&.dig(:text, :text)
      assert_includes section_text, "+10.0%"
    end

    test "shows cached prices in line when old_cached or new_cached present" do
      r = make_repriced(old_cached: 1.5, new_cached: 1.2)
      payload = digest(make_result(repriced_records: [ r ])).to_slack_payload
      section_text = payload[:blocks].find { |b| b[:type] == "section" }&.dig(:text, :text)
      assert_includes section_text, "cached"
      assert_includes section_text, "1.5"
      assert_includes section_text, "1.2"
    end

    test "omits cached string when old_cached and new_cached are both nil" do
      r = make_repriced(old_cached: nil, new_cached: nil)
      payload = digest(make_result(repriced_records: [ r ])).to_slack_payload
      section_text = payload[:blocks].find { |b| b[:type] == "section" }&.dig(:text, :text)
      refute_includes section_text, "cached"
    end

    # --- new models section --------------------------------------------------

    test "includes new models section when created_records are present" do
      result = make_result(created_records: [ make_created ])
      payload = digest(result).to_slack_payload
      refute_nil payload
      blocks = payload[:blocks]
      assert blocks.any? { |b| b.dig(:text, :text)&.include?("New models") }
    end

    test "new model line contains model name, provider, prices and edit link" do
      c = make_created(model_name: "Wonder 1", provider_name: "NewLab",
                       model_slug: "newlab-wonder-1", new_provider: false,
                       input_per_mtok: 0.1, output_per_mtok: 0.4)
      payload = digest(make_result(created_records: [ c ])).to_slack_payload
      section_text = payload[:blocks].find { |b| b[:type] == "section" }&.dig(:text, :text)
      assert_includes section_text, "Wonder 1"
      assert_includes section_text, "NewLab"
      assert_includes section_text, "edit"
      assert_includes section_text, "/admin/models/newlab-wonder-1/edit"
    end

    test "shows 'new provider' marker when new_provider is true" do
      c = make_created(provider_name: "BrandNewCo", new_provider: true)
      payload = digest(make_result(created_records: [ c ])).to_slack_payload
      section_text = payload[:blocks].find { |b| b[:type] == "section" }&.dig(:text, :text)
      assert_includes section_text, "new provider ★"
      assert_includes section_text, "BrandNewCo"
    end

    test "does not show 'new provider' marker when new_provider is false" do
      c = make_created(provider_name: "Anthropic", new_provider: false)
      payload = digest(make_result(created_records: [ c ])).to_slack_payload
      section_text = payload[:blocks].find { |b| b[:type] == "section" }&.dig(:text, :text)
      refute_includes section_text, "new provider"
    end

    # --- both sections together ---------------------------------------------

    test "includes both sections when both records arrays are populated" do
      result = make_result(
        created_records:  [ make_created ],
        repriced_records: [ make_repriced ]
      )
      payload = digest(result).to_slack_payload
      refute_nil payload
      section_texts = payload[:blocks].filter_map { |b| b.dig(:text, :text) }
      assert section_texts.any? { |t| t.include?("Price moves") }
      assert section_texts.any? { |t| t.include?("New models") }
    end

    # --- header and date formatting -----------------------------------------

    test "header block contains the formatted date" do
      result = make_result(repriced_records: [ make_repriced ])
      payload = digest(result, date: Date.new(2026, 6, 12)).to_slack_payload
      header = payload[:blocks].find { |b| b[:type] == "header" }
      assert_includes header.dig(:text, :text), "12 Jun 2026"
    end

    test "text field contains the formatted date" do
      result = make_result(repriced_records: [ make_repriced ])
      payload = digest(result, date: Date.new(2026, 6, 12)).to_slack_payload
      assert_includes payload[:text], "12 Jun 2026"
    end

    # --- fmt helper (exercised indirectly) ----------------------------------

    test "formats zero cached as '0' when cached values are 0" do
      # Zero values reach fmt via old_cached/new_cached. In Ruby, 0 is truthy,
      # so (old_cached || new_cached) is truthy and cached_str is rendered.
      r = make_repriced(old_cached: 0, new_cached: 0)
      payload = digest(make_result(repriced_records: [ r ])).to_slack_payload
      section_text = payload[:blocks].find { |b| b[:type] == "section" }&.dig(:text, :text)
      assert_includes section_text, "cached"
      # fmt(0) returns "0", not "0.00"
      assert_includes section_text, "$0→$0 cached"
    end

    # --- news section --------------------------------------------------------

    def make_news_item(overrides = {})
      NewsItem.new(
        url:       overrides.fetch(:url,       "https://anthropic.com/news/claude-5"),
        title:     overrides.fetch(:title,     "Introducing Claude 5"),
        source:    overrides.fetch(:source,    "anthropic"),
        kind:      overrides.fetch(:kind,      "release"),
        relevant:  overrides.fetch(:relevant,  true),
        rationale: overrides.fetch(:rationale, "New major model release")
      )
    end

    test "news section is present when news_items are populated" do
      item   = make_news_item
      result = make_result
      payload = SyncDigest.new(result, date: Date.new(2026, 6, 12), news_items: [ item ]).to_slack_payload
      refute_nil payload
      section_texts = payload[:blocks].filter_map { |b| b.dig(:text, :text) }
      assert section_texts.any? { |t| t.include?("News") }, "expected a News section"
    end

    test "news section shows kind and rationale for a classified item" do
      item = make_news_item(kind: "release", rationale: "New major model release",
                            relevant: true)
      result  = make_result
      payload = SyncDigest.new(result, date: Date.new(2026, 6, 12), news_items: [ item ]).to_slack_payload
      section_text = payload[:blocks].filter_map { |b| b.dig(:text, :text) }.join("\n")
      assert_includes section_text, "release"
      assert_includes section_text, "New major model release"
    end

    test "unclassified item shows warning marker instead of kind/rationale" do
      item = make_news_item(relevant: nil, kind: nil, rationale: nil)
      result  = make_result
      payload = SyncDigest.new(result, date: Date.new(2026, 6, 12), news_items: [ item ]).to_slack_payload
      section_text = payload[:blocks].filter_map { |b| b.dig(:text, :text) }.join("\n")
      assert_includes section_text, "⚠ unclassified"
    end

    test "news section includes item source and title link" do
      item = make_news_item(title: "Introducing Claude 5",
                            source: "anthropic",
                            url: "https://anthropic.com/news/claude-5")
      result  = make_result
      payload = SyncDigest.new(result, date: Date.new(2026, 6, 12), news_items: [ item ]).to_slack_payload
      section_text = payload[:blocks].filter_map { |b| b.dig(:text, :text) }.join("\n")
      assert_includes section_text, "Introducing Claude 5"
      assert_includes section_text, "anthropic.com/news/claude-5"
      assert_includes section_text, "(anthropic)"
    end

    test "returns nil when both records arrays and news_items are empty" do
      result = make_result
      payload = SyncDigest.new(result, date: Date.new(2026, 6, 12), news_items: []).to_slack_payload
      assert_nil payload
    end

    test "returns non-nil payload when only news_items are present" do
      item   = make_news_item
      result = make_result
      payload = SyncDigest.new(result, date: Date.new(2026, 6, 12), news_items: [ item ]).to_slack_payload
      refute_nil payload, "expected a payload when news_items are present even if no price/model changes"
    end
  end
end
