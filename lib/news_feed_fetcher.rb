require "rss"
require "net/http"
require "uri"
require "set"
require "nokogiri"

class NewsFeedFetcher
  TIMEOUT = 10

  # Defensive cap on stored excerpt size — generous enough to reach a story
  # buried deep in a daily digest (observed: a real aggregator's Meta mention
  # sat ~15K characters into a ~50K-character plain-text body) without storing
  # unbounded HTML from a pathological feed.
  EXCERPT_MAX_CHARS = 50_000

  # known_urls: URLs already stored as NewsItems — skips the (network-bound)
  # excerpt fallback fetch for them, since a caller only ever persists a truly
  # new item and would discard the fetched excerpt anyway.
  def self.fetch(source_config, known_urls: Set.new)
    new(source_config, known_urls:).fetch
  end

  def initialize(config, known_urls: Set.new)
    @name       = config["name"]
    @type       = config["type"]
    @url        = config["url"]
    @known_urls = known_urls
  end

  # Returns an array of {url:, title:, published_at:, source:, excerpt:} hashes.
  # excerpt is only ever populated for "rss" sources — page_diff sources
  # (Anthropic, DeepSeek) already produce one clean, single-story title per
  # anchor, not a bundled digest, so they don't have the "buried second story"
  # problem excerpt capture exists to solve; adding it would mean an extra
  # fetch per anchor on every poll, for sources that don't need it.
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
      pub   = (item.pubDate if item.respond_to?(:pubDate)) || item.date

      next if url.blank? || title.blank?
      { url: url.strip, title: title.strip,
        published_at: pub.present? ? pub.to_time.utc : nil,
        source: @name,
        excerpt: excerpt_for(item, url.strip) }
    end
    items.compact
  rescue RSS::Error => e
    Rails.logger.warn("NewsFeedFetcher(#{@name}): RSS parse error — #{e.message}")
    []
  end

  # The feed item's own body, when the feed embeds one (many aggregator
  # newsletters carry the full issue in <content:encoded>, richer than the
  # single-story <description> some feeds also include — neither is present on
  # Atom entries, only RSS's content module). Falls back to fetching the
  # item's own link when the feed carries no body at all — some feeds (e.g.
  # TLDR) are title-only, with every story only readable via the linked page.
  # Skipped for an already-known URL: the caller only persists a genuinely new
  # item, so fetching a fresh excerpt for one it already has would be
  # discarded — and RSS/page_diff runs re-see mostly-unchanged item lists every
  # poll, so this fallback fetch is the difference between one HTTP request
  # per truly-new item and one per item, every run, forever.
  def excerpt_for(item, item_url)
    html = item.respond_to?(:content_encoded) ? item.content_encoded.to_s.presence : nil
    html ||= item.respond_to?(:description) ? item.description.to_s.presence : nil
    text = if html
      strip_html(html)
    elsif @known_urls.include?(item_url)
      nil
    else
      fetch_linked_excerpt(item_url)
    end
    text.presence&.slice(0, EXCERPT_MAX_CHARS)
  end

  # A failed fallback fetch yields nil rather than aborting the batch — one
  # broken or malformed article link shouldn't drop the whole feed.
  def fetch_linked_excerpt(url)
    body = http_get(url)
    return nil if body.blank?

    strip_html(body)
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Rails.logger.warn("NewsFeedFetcher(#{@name}): excerpt fetch failed for #{url} — #{e.message}")
    nil
  end

  # <script>/<style> element text is DOM text content too — Nokogiri's #text
  # doesn't exclude it, so it has to be dropped explicitly or JS/CSS boilerplate
  # leaks into the excerpt ahead of the article body, wasting the truncation
  # budget on exactly the content this excerpt exists to skip past.
  def strip_html(html)
    doc = Nokogiri::HTML(html)
    doc.css("script, style").remove
    doc.text.squish
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
    # URI.parse accepts plenty of strings that aren't fetchable — an opaque
    # non-URL <guid>, a relative <link> — without raising: they just parse to a
    # URI with a nil host. Net::HTTP.start(nil, ...) raises Errno::EAFNOSUPPORT
    # rather than a URI error, so this has to be checked explicitly; a feed
    # item's <link>/<guid> is untrusted external content, not a vetted config
    # URL, so this is a reachable case, not just a defensive check.
    if uri.host.blank?
      Rails.logger.warn("NewsFeedFetcher(#{@name}): not a fetchable URL — #{url}")
      return nil
    end

    Net::HTTP.start(uri.host, uri.port,
                    use_ssl: uri.scheme == "https",
                    open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      response = http.get(uri.request_uri, "User-Agent" => "tokenprice-release-watch/1.0")
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("NewsFeedFetcher(#{@name}): HTTP #{response.code} for #{url}")
        return nil
      end

      body = response.body
      charset = response.type_params["charset"] || "UTF-8"
      body.encode("UTF-8", charset, invalid: :replace, undef: :replace)
    end
  rescue URI::InvalidURIError => e
    Rails.logger.warn("NewsFeedFetcher(#{@name}): invalid URL #{url} — #{e.message}")
    nil
  end
end
