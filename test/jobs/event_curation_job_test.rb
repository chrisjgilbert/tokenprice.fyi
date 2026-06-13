require "test_helper"

class EventCurationJobTest < ActiveJob::TestCase
  ONE_DRAFT = {
    drafts: [
      { title:         "DeepSeek R2: $0.14/MTok input",
        note:          "DeepSeek R2 launches at $0.14/$0.28 per MTok, undercutting frontier models 10×.",
        event_date:    "2026-06-10",
        source_url:    "https://techcrunch.com/deepseek-r2",
        confidence:    0.9,
        news_item_ids: [] }
    ]
  }.freeze

  setup do
    @news_item = NewsItem.create!(
      url:          "https://techcrunch.com/deepseek-r2",
      title:        "DeepSeek R2 launches at record-low prices",
      source:       "hn",
      relevant:     true,
      rationale:    "New model with competitive pricing",
      published_at: 3.days.ago
    )
    stub_client(ONE_DRAFT)
    @slack_original = SlackNotifier.method(:post)
    captured = @slack_payloads = []
    SlackNotifier.define_singleton_method(:post) { |payload| captured << payload; nil }
  end

  teardown do
    SlackNotifier.singleton_class.define_method(:post, @slack_original)
    if @anthropic_stubbed
      if @anthropic_original
        Anthropic::Client.singleton_class.define_method(:new, @anthropic_original)
      elsif Anthropic::Client.singleton_class.instance_methods(false).include?(:new)
        Anthropic::Client.singleton_class.remove_method(:new)
      end
    end
  end

  # --- draft creation --------------------------------------------------------

  test "creates a draft MarketEvent for each high-confidence draft" do
    assert_difference "MarketEvent.count" do
      EventCurationJob.perform_now
    end
    event = MarketEvent.last
    assert_equal "DeepSeek R2: $0.14/MTok input", event.title
    assert_equal "draft",     event.status
    assert_equal "curation",  event.source
    assert_equal Date.new(2026, 6, 10), event.event_date
    assert_equal "https://techcrunch.com/deepseek-r2", event.source_url
  end

  test "skips drafts with confidence below 0.5" do
    stub_client({ drafts: [ ONE_DRAFT[:drafts][0].merge(confidence: 0.4) ] })
    assert_no_difference "MarketEvent.count" do
      EventCurationJob.perform_now
    end
  end

  test "links news items to the created draft event" do
    stub_client({ drafts: [ ONE_DRAFT[:drafts][0].merge(news_item_ids: [ @news_item.id ]) ] })
    EventCurationJob.perform_now
    assert_equal MarketEvent.last.id, @news_item.reload.market_event_id
  end

  test "skips a draft with malformed event_date without crashing other drafts" do
    good = ONE_DRAFT[:drafts][0]
    bad  = good.merge(title: "Bad date draft", event_date: "not-a-date")
    stub_client({ drafts: [ bad, good ] })

    assert_difference "MarketEvent.count", 1 do
      EventCurationJob.perform_now
    end
    assert_equal good[:title], MarketEvent.last.title
  end

  # --- early exit ------------------------------------------------------------

  test "does nothing when no relevant unattached news items exist" do
    @news_item.update!(market_event_id: MarketEvent.create!(
      title: "Existing event", event_date: Date.current, kind: "market", status: "draft"
    ).id)

    assert_no_difference "MarketEvent.count" do
      EventCurationJob.perform_now
    end
  end

  test "creates no events when Claude returns an empty drafts array" do
    stub_client({ drafts: [] })
    assert_no_difference "MarketEvent.count" do
      EventCurationJob.perform_now
    end
  end

  # --- Slack notification ----------------------------------------------------

  test "posts a Slack notification when drafts are created" do
    EventCurationJob.perform_now
    assert_equal 1, @slack_payloads.size
    assert_match "1 market event candidate", @slack_payloads.first[:text]
  end

  test "does not post to Slack when no drafts are created" do
    stub_client({ drafts: [] })
    EventCurationJob.perform_now
    assert_empty @slack_payloads
  end

  test "Slack payload mentions plural drafts correctly" do
    two_drafts = { drafts: [
      ONE_DRAFT[:drafts][0],
      ONE_DRAFT[:drafts][0].merge(title: "Second draft", event_date: "2026-06-11")
    ] }
    stub_client(two_drafts)
    EventCurationJob.perform_now
    assert_match "2 market event candidates", @slack_payloads.first[:text]
  end

  private

  def stub_client(response_data)
    fake_block    = Struct.new(:type, :input).new(:tool_use, response_data)
    fake_response = Struct.new(:content).new([ fake_block ])
    fake_messages = Object.new
    fake_messages.define_singleton_method(:create) { |**_| fake_response }
    fake_client   = Object.new
    fake_client.define_singleton_method(:messages) { fake_messages }

    unless @anthropic_stubbed
      @anthropic_stubbed = true
      @anthropic_original = Anthropic::Client.singleton_class.instance_method(:new) rescue nil
    end
    Anthropic::Client.define_singleton_method(:new) { |**_| fake_client }
  end
end
