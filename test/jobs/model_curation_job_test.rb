require "test_helper"

class ModelCurationJobTest < ActiveJob::TestCase
  # Stub NewsItem#extract_model_candidate so the job's orchestration is tested
  # without the LLM. Driven entirely off the item's title (the job reloads items
  # from the DB, so per-instance stubs wouldn't reach them):
  #   "MODEL:<name>" → a candidate named <name>;  "ERROR…" → raises;  else → nil.
  setup do
    NewsItem.define_method(:extract_model_candidate) do
      raise NewsItem::ModelExtraction::Error, "boom" if title.include?("ERROR")

      if (m = title.match(/MODEL:(.+)/))
        ModelCandidate.new(news_item: self, name: m[1].strip, provider_name: "Acme",
                           category_slug: "image", source_url: url,
                           pricing: { "pricing_model" => "per_image", "price_summary" => "$0.04 / image" },
                           confidence: "M", status: "pending")
      end
    end

    @slack_posts   = []
    posts          = @slack_posts
    @slack_original = SlackNotifier.method(:post)
    SlackNotifier.define_singleton_method(:post) { |payload| posts << payload }
  end

  teardown do
    NewsItem.remove_method(:extract_model_candidate) if NewsItem.instance_methods(false).include?(:extract_model_candidate)
    SlackNotifier.define_singleton_method(:post, @slack_original) if @slack_original
  end

  def release(title, **attrs)
    NewsItem.create!({ title:, url: "https://ex.com/#{title.parameterize}", source: "ainews",
                       relevant: true, kind: "release", published_at: 1.hour.ago }.merge(attrs))
  end

  test "creates a candidate for each release item that yields one" do
    release("MODEL:Nano Banana 3")
    release("MODEL:Sora 3")
    release("Some funding round")           # not a model → nil

    assert_difference "ModelCandidate.count", 2 do
      ModelCurationJob.perform_now
    end
  end

  test "only processes relevant, release-kind items" do
    release("MODEL:Kept")
    release("MODEL:NotRelevant", relevant: false)
    release("MODEL:Market", kind: "market")

    ModelCurationJob.perform_now
    assert_equal %w[Kept], ModelCandidate.pluck(:name)
  end

  test "stamps processed items so they are never re-mined" do
    item = release("MODEL:Once")
    ModelCurationJob.perform_now
    assert_not_nil item.reload.curated_for_model_at

    assert_no_difference "ModelCandidate.count" do
      ModelCurationJob.perform_now
    end
  end

  test "skips a launch already in the catalog (dedup by slug)" do
    release("MODEL:Claude Opus 4.8") # slug collides with the opus fixture

    ModelCurationJob.perform_now
    assert_nil ModelCandidate.find_by(slug: "claude-opus-4-8")
  end

  test "skips a duplicate of a pending candidate already in the queue" do
    ModelCandidate.create!(name: "Repeat", provider_name: "Acme", slug: "repeat", status: "pending")
    release("MODEL:Repeat")

    assert_no_difference "ModelCandidate.count" do
      ModelCurationJob.perform_now
    end
  end

  test "an extraction error leaves the item unstamped for a later retry" do
    good = release("MODEL:Good")
    bad  = release("ERROR item")

    ModelCurationJob.perform_now

    assert_not_nil good.reload.curated_for_model_at, "clean items are stamped"
    assert_nil bad.reload.curated_for_model_at, "errored item stays unstamped for retry"
    assert_equal 1, ModelCandidate.count
  end

  test "posts a Slack nudge only when candidates were created" do
    release("Just news, no model")
    ModelCurationJob.perform_now
    assert_empty @slack_posts

    release("MODEL:Real")
    ModelCurationJob.perform_now
    assert_equal 1, @slack_posts.size
    assert_match(/candidate/i, @slack_posts.first[:text])
  end
end
