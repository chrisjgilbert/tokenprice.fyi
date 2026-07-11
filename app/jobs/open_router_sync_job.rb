# Pulls the OpenRouter model catalogue and prices every 6 hours (see
# config/recurring.yml). All the work lives in OpenRouter::ModelSync; this is
# just the schedulable Active Job wrapper.
class OpenRouterSyncJob < ApplicationJob
  queue_as :default

  def perform
    result = OpenRouter::ModelSync.call
    digest = OpenRouter::SyncDigest.new(result)

    # Announce launches before the Slack digest: SlackNotifier.post raises on a
    # non-2xx webhook, and a re-run finds no new models (created_records is
    # this-run-only), so gating launches behind Slack would silently drop them.
    announce_launches(digest)

    payload = digest.to_slack_payload
    SlackNotifier.post(payload) if payload
  end

  private

  # No idempotency stamp is needed: launch_posts is derived from created_records,
  # which holds only the models created in this run, so a re-run can't repost.
  def announce_launches(digest)
    posts = digest.launch_posts
    posts.each { |text| SocialBroadcast.post(text) }
    filtered = digest.created_count - posts.size
    Rails.logger.info(
      "OpenRouterSyncJob: announced #{posts.size} launch(es), " \
      "#{filtered} new model(s) below the provider bar"
    )
  end
end
