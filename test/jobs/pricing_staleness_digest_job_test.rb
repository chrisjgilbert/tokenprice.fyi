require "test_helper"

class PricingStalenessDigestJobTest < ActiveJob::TestCase
  setup do
    @original_post = SlackNotifier.singleton_class.instance_method(:post)
    @posted = []
    posted  = @posted
    SlackNotifier.define_singleton_method(:post) { |payload| posted << payload }
  end

  teardown do
    SlackNotifier.singleton_class.define_method(:post, @original_post)
  end

  test "posts a digest to Slack when curated prices are flagged" do
    # The fixtures include undated native prices (stt/tts), which the report flags.
    PricingStalenessDigestJob.perform_now
    assert_equal 1, @posted.size
    assert_match(/price/i, @posted.first[:text])
  end

  test "the payload names the flagged counts" do
    PricingStalenessDigestJob.perform_now
    body = @posted.first[:blocks].to_json
    # At least the undated stt/tts rows are surfaced.
    assert_match(/undated/i, body)
  end

  test "stays silent when nothing is flagged" do
    original = PricingStaleness.singleton_class.instance_method(:report)
    PricingStaleness.define_singleton_method(:report) { |*| [] }
    PricingStalenessDigestJob.perform_now
    assert_empty @posted
  ensure
    PricingStaleness.singleton_class.define_method(:report, original)
  end
end
