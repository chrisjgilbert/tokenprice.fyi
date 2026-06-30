require "net/http"
require "json"

# Thin wrapper around the Bluesky / AT Protocol posting API. Uses Net::HTTP
# directly so we don't need an extra gem. The handle and app password are read
# from encrypted credentials (bluesky: { handle:, app_password: }) — if either
# isn't set (dev/test), the call is a no-op.
#
# Posting is two calls: createSession to exchange the app password for a JWT,
# then createRecord to publish the post.
#
#   BlueskyClient.post(text: "hello")
class BlueskyClient
  HOST = "bsky.social".freeze

  def self.post(text:)
    creds = Rails.application.credentials.bluesky
    handle = creds&.dig(:handle).to_s.strip
    app_password = creds&.dig(:app_password).to_s.strip

    if handle.empty? || app_password.empty?
      Rails.logger.info("BlueskyClient: bluesky credential not set, skipping")
      return nil
    end

    session = create_session(handle, app_password)
    create_record(session.fetch("accessJwt"), session.fetch("did"), text)
  end

  def self.create_session(handle, app_password)
    response = request_json("/xrpc/com.atproto.server.createSession",
                            { identifier: handle, password: app_password })
    JSON.parse(response.body)
  end

  def self.create_record(access_jwt, did, text)
    body = {
      repo: did,
      collection: "app.bsky.feed.post",
      record: {
        "$type": "app.bsky.feed.post",
        text: text,
        createdAt: Time.current.utc.iso8601
      }
    }
    request_json("/xrpc/com.atproto.repo.createRecord", body,
                 "Authorization" => "Bearer #{access_jwt}")
  end

  def self.request_json(path, body, headers = {})
    response = Net::HTTP.start(HOST, 443,
                              use_ssl: true,
                              open_timeout: 5, read_timeout: 10) do |http|
      request = Net::HTTP::Post.new(path)
      request["Content-Type"] = "application/json"
      headers.each { |key, value| request[key] = value }
      request.body = body.to_json
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise "BlueskyClient: unexpected response #{response.code} — #{response.body}"
    end

    response
  end

  private_class_method :create_session, :create_record, :request_json
end
