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
        pct_input_change: overrides.fetch(:pct_input_change, -20.0)
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

    # A persisted model launch_posts can look the description up by slug. Only
    # slug and description matter here; the post's name/provider come from the
    # CreatedRecord.
    def make_model(slug:, description:)
      AiModel.create!(
        name: slug, slug: slug, provider: providers(:anthropic),
        source: AiModel::OPENROUTER_SOURCE, status: "active",
        description: description
      )
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
                        pct_input_change: -20.0)
      payload = digest(make_result(repriced_records: [ r ])).to_slack_payload
      section_text = payload[:blocks].find { |b| b[:type] == "section" }&.dig(:text, :text)
      assert_includes section_text, "Claude Opus 4.8"
      assert_includes section_text, "Anthropic"
      assert_includes section_text, "-20.0%"
      assert_includes section_text, "edit"
      assert_includes section_text, "/admin/models/anthropic-claude-opus-4-8/edit"
    end

    test "shows positive sign for price increase" do
      r = make_repriced(pct_input_change: 10.0)
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

    # --- launch_posts (social post strings) ---------------------------------

    test "launch_posts builds one post for an announceable provider" do
      c = make_created(model_name: "Claude Haiku 4.5", provider_name: "Anthropic",
                       model_slug: "claude-haiku-4-5",
                       input_per_mtok: 1.0, output_per_mtok: 5.0)
      posts = digest(make_result(created_records: [ c ])).launch_posts
      assert_equal 1, posts.size
      post = posts.first
      assert_includes post, "Claude Haiku 4.5"
      assert_includes post, "Anthropic"
      assert_includes post, "$1/M in"
      assert_includes post, "$5/M out"
      assert_includes post, "https://tokenprice.fyi/models/claude-haiku-4-5"
    end

    test "launch_posts excludes a non-announceable provider" do
      c = make_created(provider_name: "NewLab")
      assert_empty digest(make_result(created_records: [ c ])).launch_posts
    end

    test "launch_posts keeps only announceable records, in order" do
      records = [
        make_created(model_name: "Claude Haiku 4.5", provider_name: "Anthropic",
                     model_slug: "claude-haiku-4-5"),
        make_created(model_name: "Wonder 1", provider_name: "NewLab",
                     model_slug: "newlab-wonder-1"),
        make_created(model_name: "GPT-6 mini", provider_name: "OpenAI",
                     model_slug: "gpt-6-mini")
      ]
      posts = digest(make_result(created_records: records)).launch_posts
      assert_equal 2, posts.size
      assert_includes posts[0], "Claude Haiku 4.5"
      assert_includes posts[1], "GPT-6 mini"
    end

    test "launch_posts returns empty array with no created records" do
      assert_empty digest(make_result).launch_posts
    end

    test "launch_posts returns empty array when all records are non-announceable" do
      records = [ make_created(provider_name: "NewLab"),
                  make_created(provider_name: "ObscureCo") ]
      assert_empty digest(make_result(created_records: records)).launch_posts
    end

    test "launch_posts formats prices via fmt" do
      c = make_created(provider_name: "OpenAI",
                       input_per_mtok: 0.5, output_per_mtok: 5.0)
      post = digest(make_result(created_records: [ c ])).launch_posts.first
      assert_includes post, "$0.5/M in"
      assert_includes post, "$5/M out"
    end

    test "launch_posts stays within BlueSky's 300-character limit" do
      c = make_created(model_name: "Claude Haiku 4.5", provider_name: "Anthropic",
                       model_slug: "claude-haiku-4-5",
                       input_per_mtok: 1.0, output_per_mtok: 5.0)
      post = digest(make_result(created_records: [ c ])).launch_posts.first
      assert_operator post.length, :<=, 300
    end

    test "launch_posts includes the model's description as a news blurb" do
      make_model(slug: "acme-nova-1",
                 description: "A fast multimodal model tuned for extraction and classification.")
      c = make_created(model_name: "Nova 1", provider_name: "Anthropic",
                       model_slug: "acme-nova-1", input_per_mtok: 1.0, output_per_mtok: 5.0)

      post = digest(make_result(created_records: [ c ])).launch_posts.first
      assert_includes post, "A fast multimodal model tuned for extraction"
      assert_includes post, "https://tokenprice.fyi/models/acme-nova-1"
      assert_operator post.length, :<=, 300
    end

    test "launch_posts truncates an overlong description but keeps the link" do
      make_model(slug: "acme-verbose-1", description: "x" * 500)
      c = make_created(model_name: "Verbose 1", provider_name: "Anthropic",
                       model_slug: "acme-verbose-1")

      post = digest(make_result(created_records: [ c ])).launch_posts.first
      assert_operator post.length, :<=, 300
      assert post.end_with?("https://tokenprice.fyi/models/acme-verbose-1")
      assert_includes post, "…"
    end

    test "launch_posts flattens whitespace in a multi-line description" do
      make_model(slug: "acme-multi-1", description: "First line.\n\nSecond   line.")
      c = make_created(model_name: "Multi 1", provider_name: "Anthropic",
                       model_slug: "acme-multi-1")

      post = digest(make_result(created_records: [ c ])).launch_posts.first
      assert_includes post, "First line. Second line."
    end

    test "launch_posts falls back to name and price when the model has no description" do
      c = make_created(model_name: "Claude Haiku 4.5", provider_name: "Anthropic",
                       model_slug: "unpersisted-model",
                       input_per_mtok: 1.0, output_per_mtok: 5.0)
      post = digest(make_result(created_records: [ c ])).launch_posts.first

      assert_equal "New model: Claude Haiku 4.5 (Anthropic) — $1/M in, $5/M out.\n\n" \
                   "https://tokenprice.fyi/models/unpersisted-model", post
    end
  end
end
