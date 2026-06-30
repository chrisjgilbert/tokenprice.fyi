# Pulls the OpenRouter model catalogue and prices once a day (see
# config/recurring.yml). All the work lives in OpenRouter::ModelSync; this is
# just the schedulable Active Job wrapper.
class OpenRouterSyncJob < ApplicationJob
  queue_as :default

  def perform
    result = OpenRouter::ModelSync.call
    digest = OpenRouter::SyncDigest.new(result)

    payload = digest.to_slack_payload
    SlackNotifier.post(payload) if payload

    announce_launches(digest.launch_posts)
  end

  private

  # No idempotency stamp is needed: launch_posts is derived from created_records,
  # which holds only the models created in this run, so a re-run can't repost.
  def announce_launches(posts)
    posts.each do |text|
      post_to(BlueskyClient, text)
      post_to(MastodonClient, text)
    end
    Rails.logger.info("OpenRouterSyncJob: announced #{posts.size} launch(es)")
  end

  def post_to(client, text)
    client.post(text: text)
  rescue => e
    Rails.logger.error("OpenRouterSyncJob: #{client} failed — #{e.class}: #{e.message}")
    Honeybadger.notify(e) if defined?(Honeybadger)
  end
end
