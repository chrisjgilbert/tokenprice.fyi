# Pulls the OpenRouter model catalogue and prices once a day (see
# config/recurring.yml). All the work lives in OpenRouter::ModelSync; this is
# just the schedulable Active Job wrapper.
class OpenRouterSyncJob < ApplicationJob
  queue_as :default

  def perform
    result  = OpenRouter::ModelSync.call
    pending = NewsItem.pending_digest.to_a
    payload = OpenRouter::SyncDigest.new(result, news_items: pending).to_slack_payload

    if payload
      SlackNotifier.post(payload)
      NewsItem.where(id: pending.map(&:id)).update_all(notified_at: Time.current) if pending.any?
    end
  end
end
