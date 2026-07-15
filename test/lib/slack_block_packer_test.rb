require "test_helper"

class SlackBlockPackerTest < ActiveSupport::TestCase
  test "packs all lines into a single chunk when under the limit" do
    lines  = [ "a", "b", "c" ]
    chunks = SlackBlockPacker.pack(lines, limit: 100)
    assert_equal [ lines ], chunks
  end

  test "splits into multiple chunks once the limit is exceeded" do
    lines  = [ "x" * 40, "y" * 40, "z" * 40 ]
    chunks = SlackBlockPacker.pack(lines, limit: 50)
    assert_equal 3, chunks.size
    chunks.each { |chunk| assert_equal 1, chunk.size }
  end

  test "packs as many lines as fit before starting a new chunk" do
    lines  = [ "a" * 20, "b" * 20, "c" * 20 ]
    chunks = SlackBlockPacker.pack(lines, limit: 45)
    assert_equal [ [ "a" * 20, "b" * 20 ], [ "c" * 20 ] ], chunks
  end

  test "truncates a single line that exceeds the limit rather than dropping it" do
    chunks = SlackBlockPacker.pack([ "z" * 100 ], limit: 50)
    assert_equal 1, chunks.size
    assert_equal 50, chunks.first.first.length
    assert chunks.first.first.end_with?("…")
  end

  test "returns an empty array for empty input" do
    assert_equal [], SlackBlockPacker.pack([], limit: 100)
  end

  test "every chunk's newline-joined length stays within the limit" do
    lines  = 20.times.map { |i| "line #{i} #{"x" * 15}" }
    limit  = 60
    chunks = SlackBlockPacker.pack(lines, limit: limit)
    chunks.each { |chunk| assert_operator chunk.join("\n").length, :<=, limit }
  end
end
