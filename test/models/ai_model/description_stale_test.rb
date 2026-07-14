require "test_helper"

class AiModel::DescriptionStaleTest < ActiveSupport::TestCase
  def provider = providers(:anthropic)

  def written_up(attrs = {})
    AiModel.create!({
      provider:    provider,
      source:      AiModel::OPENROUTER_SOURCE,
      name:        "Model #{SecureRandom.hex(4)}",
      status:      "active",
      description: "d", strengths: "s", best_for: "b", limitations: "l",
      description_generated_at: Time.current
    }.merge(attrs))
  end

  test "a freshly-stamped write-up is not stale" do
    model = written_up(description_generated_at: 1.day.ago)
    assert_not_includes AiModel.description_stale, model
  end

  test "a write-up older than STALE_AFTER is stale" do
    model = written_up(description_generated_at: (AiModel::STALE_AFTER + 1.day).ago)
    assert_includes AiModel.description_stale, model
  end

  # A nil stamp means hand-written seed editorial (or an empty row): automation
  # must never overwrite it, so it is inert here regardless of source.
  test "a written-up row that was never stamped is not stale (hand-written)" do
    hand_written = written_up(source: AiModel::MANUAL_SOURCE, description_generated_at: nil)
    assert_not_includes AiModel.description_stale, hand_written
  end

  # An approved-candidate row is source: manual but its copy was generated, so it
  # carries a stamp and IS refreshed like any other generated row.
  test "a manual row with a generation stamp is stale on age like any generated row" do
    candidate = written_up(source: AiModel::MANUAL_SOURCE,
                           description_generated_at: (AiModel::STALE_AFTER + 1.day).ago)
    assert_includes AiModel.description_stale, candidate
  end

  test "a row without a write-up is never stale (it's a first-generation job)" do
    blank = written_up(strengths: nil, best_for: nil, limitations: nil,
                       description_generated_at: nil)
    assert_not_includes AiModel.description_stale, blank
  end

  test "a newer same-provider release makes an older sibling's description stale" do
    described_at = 10.days.ago
    sibling = written_up(description_generated_at: described_at, released_on: 1.year.ago)
    assert_not_includes AiModel.description_stale, sibling

    written_up(released_on: Date.current, description_generated_at: Time.current)

    assert_includes AiModel.description_stale, sibling,
                    "a launch dated after the sibling was described should flag it"
  end

  test "a sibling released before the description was written does not flag it" do
    sibling = written_up(description_generated_at: 1.day.ago, released_on: 1.year.ago)
    written_up(released_on: 30.days.ago, description_generated_at: 30.days.ago)

    assert_not_includes AiModel.description_stale, sibling
  end

  test "a retired newer sibling does not flag its siblings" do
    sibling = written_up(description_generated_at: 10.days.ago, released_on: 1.year.ago)
    written_up(status: "retired", released_on: Date.current, description_generated_at: Time.current)

    assert_not_includes AiModel.description_stale, sibling
  end

  test "stalest_description_first orders the oldest stamp first" do
    newest = written_up(description_generated_at: 10.days.ago)
    oldest = written_up(description_generated_at: 200.days.ago)
    middle = written_up(description_generated_at: 100.days.ago)

    ordered = AiModel.where(id: [ newest, oldest, middle ].map(&:id))
                     .stalest_description_first.to_a

    assert_equal [ oldest, middle, newest ], ordered
  end
end
