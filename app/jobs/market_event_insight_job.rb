# Generates the "so what" for a market event out of band. Enqueued per draft by
# EventCurationJob, and reused by the backfill task. Non-fatal: a generation
# failure is logged, not raised, so a flaky web search doesn't poison the queue
# or leave the event unpublishable — the backfill task can fill blanks later.
class MarketEventInsightJob < ApplicationJob
  queue_as :default

  def perform(event)
    event.generate_insight
  rescue MarketEvent::Insight::Error => e
    Rails.logger.warn("MarketEventInsightJob: #{e.message} (event ##{event.id})")
    Honeybadger.notify(e) if defined?(Honeybadger)
  end
end
