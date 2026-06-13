require "net/http"
require "uri"
require "json"

class HnAlgoliaFetcher
  BASE_URL = "https://hn.algolia.com/api/v1/search_by_date"
  TIMEOUT  = 10

  def self.fetch(query:, since:, min_points: 25)
    new(query: query, since: since, min_points: min_points).fetch
  end

  def initialize(query:, since:, min_points:)
    @query      = query
    @since      = since.to_i
    @min_points = min_points
  end

  def fetch
    body = http_get(build_uri)
    return [] if body.nil?

    data = JSON.parse(body)
    parse_hits(data["hits"] || [])
  rescue JSON::ParserError => e
    Rails.logger.warn("HnAlgoliaFetcher(#{@query}): JSON parse error — #{e.message}")
    []
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Rails.logger.warn("HnAlgoliaFetcher(#{@query}): network error — #{e.message}")
    []
  end

  private

  def build_uri
    params = URI.encode_www_form(
      query:          @query,
      tags:           "story",
      numericFilters: "points>#{@min_points},created_at_i>#{@since}",
      hitsPerPage:    50
    )
    URI.parse("#{BASE_URL}?#{params}")
  end

  def parse_hits(hits)
    hits.filter_map do |hit|
      title = hit["title"].to_s.strip
      next if title.blank?
      url = hit["url"].presence || "https://news.ycombinator.com/item?id=#{hit["objectID"]}"
      { url:          url,
        title:        title,
        source:       "hn",
        published_at: Time.at(hit["created_at_i"]).utc }
    end
  end

  def http_get(uri)
    Net::HTTP.start(uri.host, uri.port,
                    use_ssl:      uri.scheme == "https",
                    open_timeout: TIMEOUT,
                    read_timeout: TIMEOUT) do |http|
      response = http.get(uri.request_uri, "User-Agent" => "tokenprice-news-scan/1.0")
      return nil unless response.is_a?(Net::HTTPSuccess)
      response.body
    end
  rescue URI::InvalidURIError => e
    Rails.logger.warn("HnAlgoliaFetcher(#{@query}): invalid URI — #{e.message}")
    nil
  end
end
