require "net/http"
require "json"

# Thin wrapper around the Mastodon statuses API. Uses Net::HTTP directly so we
# don't need an extra gem. The instance URL and access token are read from
# encrypted credentials (mastodon: { instance_url:, access_token: }) — if either
# isn't set (dev/test), the call is a no-op.
#
#   MastodonClient.post(text: "hello")
class MastodonClient
  def self.post(text:)
    creds = Rails.application.credentials.mastodon
    instance_url = creds&.dig(:instance_url).to_s.strip
    access_token = creds&.dig(:access_token).to_s.strip

    if instance_url.empty? || access_token.empty?
      Rails.logger.info("MastodonClient: mastodon credential not set, skipping")
      return nil
    end

    uri = URI.parse("#{instance_url.chomp('/')}/api/v1/statuses")
    unless uri.scheme == "https"
      raise "MastodonClient: instance URL must be https, got #{uri.scheme.inspect}"
    end

    response = Net::HTTP.start(uri.host, uri.port,
                              use_ssl: true,
                              open_timeout: 5, read_timeout: 10) do |http|
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request["Authorization"] = "Bearer #{access_token}"
      request.body = { status: text }.to_json
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "MastodonClient: unexpected response #{response.code} — #{response.body}"
    end

    response
  end
end
