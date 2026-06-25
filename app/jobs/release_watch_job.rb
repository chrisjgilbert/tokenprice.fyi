# Polls provider news feeds every ~6 hours, stores new entries in news_items,
# and classifies each with Claude Haiku. Relevant items join the daily Slack digest
# via the notified_at IS NULL pending pool flushed by NewsDigestJob.
class ReleaseWatchJob < ApplicationJob
  queue_as :default

  def perform
    sources = YAML.safe_load_file(sources_file)["sources"]
    new_count = 0

    sources.each do |source_config|
      items = NewsFeedFetcher.fetch(source_config)
      items.each do |item|
        news_item = create_news_item(item)
        next unless news_item

        classify(news_item)
        new_count += 1
      end
    end

    Rails.logger.info("ReleaseWatchJob: processed #{new_count} new item(s)")
  end

  private

  def sources_file = Rails.root.join("config/news_sources.yml")

  def create_news_item(attrs)
    NewsItem.create!(
      url:          attrs[:url],
      title:        attrs[:title],
      source:       attrs[:source],
      published_at: attrs[:published_at]
    )
  rescue ActiveRecord::RecordNotUnique
    # URL already seen — skip silently
    nil
  end

  def classify(item)
    result = NewsClassifier.classify(title: item.title, source: item.source)
    item.update!(
      relevant:  result[:relevant],
      kind:      result[:kind],
      rationale: result[:rationale]
    )
  rescue NewsClassifier::ClassifyError => e
    Rails.logger.warn("ReleaseWatchJob: classifier error for #{item.url} — #{e.message}")
    # Leave relevant=nil (unclassified) — item will still surface in digest flagged
  end
end
