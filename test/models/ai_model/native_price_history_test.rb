require "test_helper"

class AiModel::NativePriceHistoryTest < ActiveSupport::TestCase
  test "changing a native price appends a snapshot instead of only overwriting" do
    model = ai_models(:image_priced)
    assert_difference -> { model.native_price_snapshots.count }, 1 do
      model.update!(price_summary: "$0.05 / image", priced_as_of: Date.new(2026, 8, 1))
    end
    snap = model.native_price_snapshots.chronological.last
    assert_equal "$0.05 / image", snap.price_summary
    assert_equal Date.new(2026, 8, 1), snap.priced_as_of
  end

  test "editing a non-price field does not append a snapshot" do
    model = ai_models(:image_priced)
    assert_no_difference -> { model.native_price_snapshots.count } do
      model.update!(description: "A tweak to the blurb.")
    end
  end

  test "a token-only model never appends a native snapshot" do
    model = ai_models(:opus)
    assert_no_difference -> { model.native_price_snapshots.count } do
      model.update!(name: "Claude Opus 4.8 (rev)")
    end
  end

  test "clearing a native price records nothing (no negative-space snapshot)" do
    model = ai_models(:image_priced)
    assert_no_difference -> { model.native_price_snapshots.count } do
      model.update!(price_summary: nil, native_price_usd: nil)
    end
  end
end
