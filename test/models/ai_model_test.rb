require "test_helper"

class AiModelTest < ActiveSupport::TestCase
  test "current_price is the most recent snapshot" do
    assert_equal price_points(:deepseek_cut), ai_models(:deepseek_v4).current_price
  end

  test "launch_price is the earliest snapshot" do
    assert_equal price_points(:deepseek_launch), ai_models(:deepseek_v4).launch_price
  end

  test "input/output change since launch reflects the DeepSeek 75% cut" do
    # Both dimensions were cut 75% (1.74→0.435 in, 3.48→0.87 out).
    assert_in_delta(-75.0, ai_models(:deepseek_v4).input_change_since_launch, 0.1)
    assert_in_delta(-75.0, ai_models(:deepseek_v4).output_change_since_launch, 0.1)
  end

  test "single-snapshot model reports no change" do
    assert_nil ai_models(:opus).input_change_since_launch
    assert_nil ai_models(:opus).output_change_since_launch
    assert_not ai_models(:opus).price_changed?
  end

  test "price_as_of returns the snapshot in effect on a date" do
    ds = ai_models(:deepseek_v4)
    # deepseek_launch is 2026-02-01, deepseek_cut is 2026-05-31.
    assert_nil ds.price_as_of(Date.new(2026, 1, 1))
    assert_equal price_points(:deepseek_launch), ds.price_as_of(Date.new(2026, 2, 1))
    assert_equal price_points(:deepseek_launch), ds.price_as_of(Date.new(2026, 5, 30))
    assert_equal price_points(:deepseek_cut),    ds.price_as_of(Date.new(2026, 6, 1))
  end

  test "price_change_over since launch matches input_change_since_launch" do
    ds = ai_models(:deepseek_v4)
    assert_in_delta(-75.0, ds.price_change_over(:input, :launch), 0.1)
    assert_in_delta ds.input_change_since_launch, ds.price_change_over(:input, :launch), 0.0001
  end

  test "price_change_over trailing window captures a move within it" do
    travel_to Date.new(2026, 6, 11) do
      ds = ai_models(:deepseek_v4)
      # The 75% cut (2026-05-31) falls inside all of these windows.
      assert_in_delta(-75.0, ds.price_change_over(:input, 30.days), 0.1)
      assert_in_delta(-75.0, ds.price_change_over(:input, 90.days), 0.1)
      assert_in_delta(-75.0, ds.price_change_over(:input, 1.year), 0.1)
    end
  end

  test "price_change_over is nil when the price is flat across the window" do
    travel_to Date.new(2026, 6, 11) do
      # A window starting after the cut sees only the post-cut price — no move.
      assert_nil ai_models(:deepseek_v4).price_change_over(:input, 2.days)
      # Single-snapshot model never has a move to report.
      assert_nil ai_models(:opus).price_change_over(:input, 30.days)
    end
  end

  test "price_change_over resolves each window to its own reference and signs both ways" do
    travel_to Date.new(2026, 6, 11) do
      model = providers(:anthropic).ai_models.create!(name: "Window Probe", tier: "mid")
      # Launched long ago at 10, hiked to 20 (Apr), trimmed to 15 (Jun) — current.
      model.price_points.create!(effective_on: Date.new(2025, 1, 1),  input_per_mtok: 10, output_per_mtok: 10)
      model.price_points.create!(effective_on: Date.new(2026, 4, 12), input_per_mtok: 20, output_per_mtok: 20)
      model.price_points.create!(effective_on: Date.new(2026, 6, 1),  input_per_mtok: 15, output_per_mtok: 15)
      model.forget_price_cache!

      # 30d → reference is the Apr hike (20): 20→15 = −25% (distinguishes the window).
      assert_in_delta(-25.0, model.price_change_over(:input, 30.days), 0.1)
      # 90d and launch reach back past the hike to the original 10: 10→15 = +50% (positive delta).
      assert_in_delta(50.0,  model.price_change_over(:input, 90.days), 0.1)
      assert_in_delta(50.0,  model.price_change_over(:input, :launch), 0.1)
      # A window older than the model clamps to launch, matching :launch exactly.
      assert_equal model.price_change_over(:input, :launch), model.price_change_over(:input, 10.years)
    end
  end

  test "price_changes returns input and output percentages for every window in order" do
    travel_to Date.new(2026, 6, 11) do
      changes = ai_models(:deepseek_v4).price_changes
      assert_equal [ "30d", "90d", "1y", "Since launch" ], changes.map(&:label)
      assert changes.all? { |c| c.input.present? && c.output.present? }
    end
  end

  test "slug is auto-generated from name on create" do
    model = ai_models(:opus).provider.ai_models.create!(name: "Claude Test 9", tier: "mid")
    assert_equal "claude-test-9", model.slug
  end

  test "tier and status reject invalid values" do
    model = AiModel.new(provider: providers(:anthropic), name: "X", tier: "nope")
    assert_not model.valid?
  end

  test "listed excludes models with no price points" do
    listed = AiModel.listed
    assert_includes listed, ai_models(:opus)
    assert_includes listed, ai_models(:deepseek_v4)
    assert_not_includes listed, ai_models(:no_price)
    assert_not_includes listed, ai_models(:retired_instant)
  end

  test "listed includes a price-less non-text directory row but not a price-less text row" do
    listed = AiModel.listed
    # An image-generation row with no price points is now a visible directory entry.
    assert_includes listed, ai_models(:image_gen)
    # A price-less plain-text row stays hidden — we have no data on it.
    assert_not_includes listed, ai_models(:no_price)
  end

  test "listed returns each priced model exactly once" do
    ids = AiModel.listed.pluck(:id)
    assert_equal ids.uniq, ids
  end

  test "listed excludes a price-less multimodal row (token-priced, not a directory class)" do
    # Multimodal bills per token, so a price-less one is just missing data, not a
    # directory entry to surface "not yet tracked".
    model = ai_models(:no_price)
    model.update!(input_modalities: %w[text image], output_modalities: %w[text])
    assert_equal :multimodal, model.modality_class
    assert_not_includes AiModel.listed, model
  end

  test "sort_for_display sinks price-less rows to the bottom on a price sort in both directions" do
    priced    = ai_models(:opus)        # has price points
    priceless = ai_models(:image_gen)   # directory row, no price
    by = ->(m) { m.current_input || Float::INFINITY }

    asc  = AiModel.sort_for_display([ priceless, priced ], by: by, dir: "asc",  price_sort: true)
    desc = AiModel.sort_for_display([ priced, priceless ], by: by, dir: "desc", price_sort: true)

    assert_equal priceless, asc.last,  "price-less row sinks last ascending"
    assert_equal priceless, desc.last, "price-less row sinks last descending too"
  end

  test "sort_for_display leaves price-less rows in normal order on a non-price sort" do
    priced    = ai_models(:opus)
    priceless = ai_models(:image_gen)
    by = ->(m) { m.name.to_s.downcase } # "claude opus 4.8" < "pixel forge 1"

    sorted = AiModel.sort_for_display([ priceless, priced ], by: by, dir: "asc", price_sort: false)
    assert_equal [ priced, priceless ], sorted, "non-price sort orders by name, no sink"
  end

  test "directory_listing? is true only for a live, price-less, directory-class row" do
    assert ai_models(:image_gen).directory_listing?, "price-less image-gen row"
    assert_not ai_models(:no_price).directory_listing?, "price-less text row is not a directory listing"
    assert_not ai_models(:opus).directory_listing?, "a priced row is not a directory listing"

    ai_models(:image_gen).update!(status: "retired")
    assert_not ai_models(:image_gen).reload.directory_listing?, "a retired row is not a directory listing"
  end

  test "modality_class is stored on save and matches the derived value" do
    model = providers(:anthropic).ai_models.create!(
      name: "Stored Class Probe", tier: "mid",
      input_modalities: %w[text], output_modalities: %w[image]
    )
    assert_equal "image_generation", model.read_attribute(:modality_class)
    assert_equal :image_generation, model.modality_class
  end

  test "modality_class returns a symbol on an unsaved record" do
    model = AiModel.new(input_modalities: %w[image text], output_modalities: %w[text])
    assert_equal :multimodal, model.modality_class
  end

  test "changing input_modalities updates the stored class on save" do
    model = providers(:anthropic).ai_models.create!(
      name: "Reclass Probe", tier: "mid",
      input_modalities: %w[text], output_modalities: %w[text]
    )
    assert_equal "text", model.read_attribute(:modality_class)

    model.update!(output_modalities: %w[image])
    assert_equal "image_generation", model.read_attribute(:modality_class)
    assert_equal :image_generation, model.modality_class
  end

  test "suspended is a valid status that stays listed, unlike retired" do
    fable = ai_models(:suspended_fable)
    assert fable.suspended?
    assert fable.valid?
    # Suspended models are shown (flagged), not hidden like retired ones.
    assert_includes AiModel.listed, fable
  end

  test "matches? finds substrings of name, provider and slug" do
    model = ai_models(:opus)
    assert model.matches?("opus")
    assert model.matches?("Anthropic")
    assert model.matches?("claude-opus")
  end

  test "matches? forgives punctuation differences and typos" do
    model = ai_models(:opus)
    assert model.matches?("opus 4.8")
    assert model.matches?("opus48")
    assert model.matches?("antropic"), "subsequence match should forgive a dropped letter"
  end

  test "matches? requires every query word to match" do
    assert_not ai_models(:opus).matches?("opus gemini")
    assert_not ai_models(:opus).matches?("deepseek")
  end

  test "matches? does not subsequence-match across word boundaries" do
    # Each is an in-order letter pick from "claudeopus48" but no single word.
    %w[cap lap cs4 la8].each do |junk|
      assert_not ai_models(:opus).matches?(junk), "#{junk.inspect} should not match Claude Opus 4.8"
    end
    # Within a single word a dropped letter still matches ("opus" sans u).
    assert ai_models(:opus).matches?("ops")
  end

  test "matches? accepts everything for a blank query" do
    assert ai_models(:opus).matches?("")
    assert ai_models(:opus).matches?(nil)
  end


  test "long_description folds editorial facets into the lede" do
    model = ai_models(:opus)
    model.update!(strengths: "Fast", best_for: "Agents", limitations: "Pricey")
    desc = model.long_description
    assert_includes desc, "Test model."
    assert_includes desc, "Strengths: Fast."
    assert_includes desc, "Best for: Agents."
    assert_includes desc, "Limitations: Pricey."
  end

  test "long_description is nil when nothing is set" do
    model = ai_models(:no_price)
    model.update!(description: nil)
    assert_nil model.long_description
  end

  test "latest_price_move brackets the two most recent snapshots and reports both dimensions" do
    move = ai_models(:deepseek_v4).latest_price_move

    assert_equal price_points(:deepseek_launch), move.from
    assert_equal price_points(:deepseek_cut), move.to
    assert_in_delta(-75.0, move.input, 0.1)
    assert_in_delta(-75.0, move.output, 0.1)
    assert_equal Date.new(2026, 5, 31), move.date
  end

  test "latest_price_move is nil for a single-snapshot model" do
    assert_nil ai_models(:opus).latest_price_move
  end

  test "latest_price_move is nil when the latest snapshots share the same price" do
    model = ai_models(:opus)
    model.price_points.create!(effective_on: Date.new(2026, 6, 1),
                               input_per_mtok: 5, output_per_mtok: 25)

    assert_nil model.reload.latest_price_move
  end

  test "latest_price_move is nil when only the cached price moved" do
    model = ai_models(:opus)
    model.price_points.create!(effective_on: Date.new(2026, 6, 1),
                               input_per_mtok: 5, output_per_mtok: 25,
                               cached_input_per_mtok: 0.25)

    assert_nil model.reload.latest_price_move
  end

  test "latest_price_move ignores a backdated snapshot inserted before the latest pair" do
    model = ai_models(:deepseek_v4)
    model.price_points.create!(effective_on: Date.new(2026, 1, 1),
                               input_per_mtok: 99, output_per_mtok: 99)

    assert_equal price_points(:deepseek_cut), model.reload.latest_price_move.to
  end

  test "price helpers use the eager-loaded association without extra queries" do
    model = AiModel.includes(:price_points).find(ai_models(:deepseek_v4).id)
    assert_queries_count(0) do
      model.current_price
      model.launch_price
      model.input_change_since_launch
    end
  end

  test "a blank openrouter_id normalizes to nil" do
    model = ai_models(:opus)
    model.update!(openrouter_id: "   ")
    assert_nil model.reload.openrouter_id
  end

  test "openrouter_id must be unique across models" do
    ai_models(:opus).update!(openrouter_id: "anthropic/claude-opus-4-8")
    dup = ai_models(:deepseek_v4)
    dup.openrouter_id = "anthropic/claude-opus-4-8"

    refute dup.valid?
    assert_includes dup.errors[:openrouter_id], "has already been taken"
  end

  test "modalities read back as arrays, defaulting to empty for untouched rows" do
    model = ai_models(:opus)
    assert_equal [], model.input_modalities
    assert_equal [], model.output_modalities
  end

  test "a model with empty modalities degrades to the text class" do
    assert_equal :text, ai_models(:opus).modality_class
    assert_not ai_models(:opus).multimodal?
  end

  test "modality_class derives from the recorded signature" do
    model = ai_models(:opus)
    model.update!(input_modalities: %w[image text], output_modalities: %w[text])
    assert_equal :multimodal, model.modality_class

    model.update!(input_modalities: %w[text], output_modalities: %w[image])
    assert_equal :image_generation, model.modality_class
  end

  test "multimodal? is true when input accepts a non-text modality" do
    model = ai_models(:opus)
    model.update!(input_modalities: %w[image text], output_modalities: %w[text])
    assert model.multimodal?

    model.update!(input_modalities: %w[text], output_modalities: %w[text])
    assert_not model.multimodal?

    model.update!(input_modalities: [], output_modalities: [])
    assert_not model.multimodal?
  end
end
