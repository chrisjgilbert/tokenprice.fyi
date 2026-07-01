require "test_helper"

class SoWhatTest < ActiveSupport::TestCase
  test "passes a well-behaved two-sentence so_what through untouched" do
    text = "During peak hours API pricing doubles, so deepseek-v4-pro output jumps from ¥6 to ¥12 per " \
           "million tokens. Anyone batching large jobs now needs to schedule non-urgent inference for " \
           "off-peak windows."

    assert_operator text.length, :<=, SoWhat::LIMIT
    assert_equal text, SoWhat.clamp(text)
  end

  test "strips surrounding whitespace" do
    assert_equal "why it matters", SoWhat.clamp("  why it matters  ")
  end

  test "trims an over-long answer at a sentence boundary when one sits deep enough" do
    first  = "This first sentence carries the headline figure and comfortably fills more than half of the " \
             "available window, running well past two hundred characters so the clamp is confident it can " \
             "keep the whole sentence rather than a stub."
    assert_operator first.length, :>=, SoWhat::LIMIT / 2
    result = SoWhat.clamp("#{first} A trailing thought that pushes past the limit " + "x " * 200)

    assert_equal first, result
    refute_includes result, "…"
  end

  test "never cuts mid-word, falling back to a word boundary with an ellipsis" do
    text   = "word " * 200
    result = SoWhat.clamp(text)

    assert_operator result.length, :<=, SoWhat::LIMIT
    assert result.end_with?("…")
    refute_match(/\bwor…\z/, result)
    assert_equal result, result.rstrip
  end

  test "handles a runaway single word without whitespace" do
    result = SoWhat.clamp("A" * 500)

    assert_operator result.length, :<=, SoWhat::LIMIT
  end
end
