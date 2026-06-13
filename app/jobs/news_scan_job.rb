class NewsScanJob < ApplicationJob
  queue_as :default

  CACHE_KEY  = "news_scan_job/last_run_at"
  MIN_POINTS = 25

  def perform
    since     = Rails.cache.read(CACHE_KEY) || 24.hours.ago
    queries   = Provider.pluck(:name)
    seen_urls = Set.new
    new_count = 0

    queries.each do |term|
      HnAlgoliaFetcher.fetch(query: term, since: since, min_points: MIN_POINTS).each do |item|
        next unless seen_urls.add?(item[:url])
        news_item = create_news_item(item)
        next unless news_item
        classify(news_item)
        new_count += 1
      end
    end

    Rails.cache.write(CACHE_KEY, Time.current)
    Rails.logger.info("NewsScanJob: processed #{new_count} new item(s) from #{queries.size} queries")
  end

  private

  def create_news_item(attrs)
    NewsItem.create!(
      url:          attrs[:url],
      title:        attrs[:title],
      source:       attrs[:source],
      published_at: attrs[:published_at]
    )
  rescue ActiveRecord::RecordNotUnique
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
    Rails.logger.warn("NewsScanJob: classifier error for #{item.url} — #{e.message}")
  end
end
