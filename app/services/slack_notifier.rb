require "net/http"
require "json"

# Thin wrapper around the Slack incoming-webhook API. Uses Net::HTTP directly
# so we don't need an extra gem. The webhook URL is read from encrypted
# credentials (slack_webhook_url) — if it isn't set (dev/test), the call is a
# no-op.
#
#   SlackNotifier.post(text: "hello")
class SlackNotifier
  def self.post(payload)
    url = Rails.application.credentials.slack_webhook_url

    unless url
      Rails.logger.info("SlackNotifier: slack_webhook_url credential not set, skipping")
      return nil
    end

    uri = URI.parse(url)
    response = Net::HTTP.start(uri.host, uri.port,
                               use_ssl: uri.scheme == "https",
                               open_timeout: 5, read_timeout: 10) do |http|
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
