require "rss"
require "net/http"
require "uri"
require "set"

class NewsFeedFetcher
  TIMEOUT = 10

  def self.fetch(source_config)
    new(source_config).fetch
  end

  def initialize(config)
    @name   = config["name"]
    @type   = config["type"]
    @url    = config["url"]
  end

  # Returns an array of {url:, title:, published_at:, source:} hashes.
  def fetch
    case @type
    when "rss"       then fetch_rss
    when "page_diff" then fetch_page_diff
    else raise ArgumentError, "Unknown feed type: #{@type}"
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Rails.logger.warn("NewsFeedFetcher(#{@name}): network error — #{e.message}")
    []
  end

  private

  def fetch_rss
    body = http_get(@url)
    return [] if body.blank?

    feed = RSS::Parser.parse(body, false)
    return [] unless feed

    items = feed.items.map do |item|
      url   = item.link.to_s.presence || item.guid&.content.to_s
      title = item.title.to_s
      pub   = item.pubDate || item.date

      next if url.blank? || title.blank?
      { url: url.strip, title: title.strip,
        published_at: pub.present? ? pub.to_time.utc : nil,
        source: @name }
    end
    items.compact
  rescue RSS::Error => e
    Rails.logger.warn("NewsFeedFetcher(#{@name}): RSS parse error — #{e.message}")
    []
  end

  def fetch_page_diff
    body = http_get(@url)
    return [] if body.blank?

    base_uri = URI.parse(@url)
    seen     = Set.new

    body.scan(/<a[^>]+href=["']([^"']+)["'][^>]*>(.*?)<\/a>/im).filter_map do |href, anchor_text|
      url = begin
        URI.join(base_uri, href.strip).to_s
      rescue URI::Error
        next
      end
      next if seen.include?(url)
      next unless url.start_with?("http")
      seen << url

      title = anchor_text.gsub(/<[^>]+>/, "").strip
      next if title.blank?
      next if title.length < 10  # skip nav links

      { url: url, title: title, published_at: nil, source: @name }
    end
  rescue URI::Error => e
    Rails.logger.warn("NewsFeedFetcher(#{@name}): URI error — #{e.message}")
    []
  end

  def http_get(url)
    uri = URI.parse(url)
    Net::HTTP.start(uri.host, uri.port,
                    use_ssl: uri.scheme == "https",
                    open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      response = http.get(uri.request_uri, "User-Agent" => "tokenprice-release-watch/1.0")
      return nil unless response.is_a?(Net::HTTPSuccess)
      response.body
    end
  rescue URI::InvalidURIError => e
    Rails.logger.warn("NewsFeedFetcher(#{@name}): invalid URL #{url} — #{e.message}")
    nil
  end
end
