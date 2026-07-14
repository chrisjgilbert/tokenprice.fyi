require "test_helper"

# Guards the real config/news_sources.yml that ReleaseWatchJob polls. A malformed
# addition (missing key, unknown type, http URL) would fail silently at runtime —
# NewsFeedFetcher would just return nothing for that source — so validate the file
# structurally here, and assert the launch-focused aggregator feeds are present.
class NewsSourcesConfigTest < ActiveSupport::TestCase
  SOURCES = YAML.safe_load_file(Rails.root.join("config/news_sources.yml")).fetch("sources")
  ALLOWED_TYPES = %w[rss page_diff].freeze

  def names = SOURCES.map { |s| s["name"] }

  test "every source has a name, an allowed type, and an https url" do
    SOURCES.each do |source|
      assert source["name"].present?, "a source is missing a name"
      assert_includes ALLOWED_TYPES, source["type"], "#{source["name"]} has an unknown type"
      assert source["url"].to_s.start_with?("https://"), "#{source["name"]} url must be https"
    end
  end

  test "source names are unique" do
    assert_equal names, names.uniq, "duplicate source name in news_sources.yml"
  end

  test "includes the launch-focused aggregator newsletters" do
    assert_includes names, "ainews"        # smol.ai AINews — launch-complete
    assert_includes names, "latent_space"  # Latent Space
    assert_includes names, "tldr_ai"       # TLDR AI
  end

  test "keeps the first-party provider feeds that already catch launches" do
    assert_includes names, "openai"
    assert_includes names, "anthropic"
  end

  test "does not poll the dead meta_ai feed" do
    # ai.meta.com/blog/rss 404s with no autodiscoverable replacement; Meta
    # launches still reach us via the aggregator feeds and HN. Re-add once a
    # working feed exists — see the comment in news_sources.yml.
    assert_not_includes names, "meta_ai"
  end
end
