# Fans one text out to every social channel, non-fatally: a failure on one
# platform must not stop the others or raise to the caller, so the flows that
# trigger a broadcast (the admin publish action, the daily sync job) never 500
# or fail on a flaky social API. Each client no-ops when its credential is unset.
#
#   SocialBroadcast.post("New model: …")
class SocialBroadcast
  # BlueSky caps a post at 300 characters; Mastodon's is higher, so 300 is the
  # safe ceiling for a message fanned to every channel. Callers compose within
  # this before broadcasting (the text is built once and sent to all sinks).
  CHAR_LIMIT = 300

  def self.post(text)
    [ BlueskyClient, MastodonClient ].each do |client|
      client.post(text: text)
    rescue => e
      Rails.logger.error("SocialBroadcast: #{client} failed — #{e.class}: #{e.message}")
      Honeybadger.notify(e) if defined?(Honeybadger)
    end
  end
end
