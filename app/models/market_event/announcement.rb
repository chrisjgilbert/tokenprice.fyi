# Posts a published MarketEvent to BlueSky and Mastodon. Reached through
# MarketEvent#announce; never called directly. Idempotent (guards on status +
# announced_at) and non-fatal: a posting failure is logged, not raised, so the
# admin publish action never 500s on a flaky social API.
class MarketEvent::Announcement
  BASE_URL = "https://tokenprice.fyi"
  EVENTS_URL = "#{BASE_URL}/events"
  CHAR_LIMIT = 300

  def initialize(event)
    @event = event
  end

  def run
    return unless announceable?

    SocialBroadcast.post(post_text)

    # A single stamp (not one per platform) is deliberate for v1: it prevents
    # re-posting to the platform that succeeded if the other was flaky. Per-platform
    # tracking is deferred (see SOCIAL_PRESENCE_PLAN.md, P1).
    @event.update_column(:announced_at, Time.current)
  rescue => e
    Rails.logger.error("MarketEvent::Announcement: #{e.class} — #{e.message}")
    Honeybadger.notify(e) if defined?(Honeybadger)
  end

  private

  def announceable?
    @event.status == "published" && @event.announced_at.nil?
  end

  def post_text
    # The "so what" is the more shareable line, so it leads the body when present;
    # the note is the fallback for events that haven't been given one yet.
    blurb = (@event.so_what.presence || @event.note).to_s.strip.presence
    body = [ @event.title, blurb ].compact.join("\n\n")
    suffix = "\n\n#{EVENTS_URL}"
    "#{body.truncate(CHAR_LIMIT - suffix.length, omission: '…')}#{suffix}"
  end
end
