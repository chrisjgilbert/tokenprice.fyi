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
    url = Rails.application.credentials.slack_webhook_url.to_s.strip

    if url.empty?
      Rails.logger.info("SlackNotifier: slack_webhook_url credential not set, skipping")
      return nil
    end

    uri = URI.parse(url)
    unless uri.scheme == "https"
      raise "SlackNotifier: webhook URL must be https, got #{uri.scheme.inspect} " \
            "(a plaintext URL silently redirects and the POST is lost)"
    end

    response = Net::HTTP.start(uri.host, uri.port,
                               use_ssl: true,
                               open_timeout: 5, read_timeout: 10) do |http|
      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = payload.to_json
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      # A real Slack webhook returns 200 "ok"; a 3xx means we hit something that
      # redirects (wrong URL/host). Surface the Location instead of reading the
      # body, which on a redirect isn't available outside the request block.
      detail = if response.is_a?(Net::HTTPRedirection)
                 location = response["location"]
                 location.present? ? "redirect to #{location}" : "redirect (no Location header — webhook URL is likely deactivated)"
      else
                 response.body
      end
      raise "SlackNotifier: unexpected response #{response.code} — #{detail}"
    end

    response
  end
end
