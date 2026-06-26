class NewsScanJob < ApplicationJob
  queue_as :default

  CACHE_KEY  = "news_scan_job/last_run_at"
  MIN_POINTS = 25

  def perform
    queries = Provider.pluck(:name)
    if queries.empty?
      Rails.logger.info("NewsScanJob: no providers found, skipping")
      return
    end

    since     = Rails.cache.read(CACHE_KEY) || 24.hours.ago.to_i
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

    Rails.cache.write(CACHE_KEY, Time.current.to_i)
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
    result = item.classify
    item.update!(
      relevant:  result[:relevant],
      kind:      result[:kind],
      rationale: result[:rationale]
    )
  rescue NewsItem::Classification::Error => e
    Rails.logger.warn("NewsScanJob: classifier error for #{item.url} — #{e.message}")
  end
end
