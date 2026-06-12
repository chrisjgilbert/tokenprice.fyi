require "net/http"
require "json"

# Thin wrapper around the Slack incoming-webhook API. Uses Net::HTTP directly
# so we don't need an extra gem. The webhook URL is injected at runtime via
# SLACK_WEBHOOK_URL — if it isn't set (dev/test), the call is a no-op.
#
#   SlackNotifier.post(text: "hello")
class SlackNotifier
  def self.post(payload)
    url = ENV["SLACK_WEBHOOK_URL"]

    unless url
      Rails.logger.info("SlackNotifier: SLACK_WEBHOOK_URL not set, skipping")
      return nil
    end

    uri = URI.parse(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = payload.to_json
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "SlackNotifier: unexpected response #{response.code} — #{response.body}"
    end

    response
  end
end
