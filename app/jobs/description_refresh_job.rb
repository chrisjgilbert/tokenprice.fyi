# Rewrites stale editorial copy. Descriptions are generated once and then frozen,
# so they drift as models mature and as newer siblings reframe them; this job
# regenerates the ones AiModel.description_stale flags (age, or a newer
# same-provider release) on a rolling daily cadence.
#
# Covers every row with generated copy regardless of source — an OpenRouter
# import or an approved candidate (source: manual, but LLM-written). The gate is
# description_stale, which keys off the generation stamp, so hand-written seed
# editorial (no stamp) is never touched. Capped per run and non-fatal per model —
# a flaky API call is logged, not raised, so it doesn't poison the queue, and the
# row it skipped is still stale and picked up on a later run. The cap plus the
# daily schedule drains the whole catalogue well within the STALE_AFTER window
# rather than firing a monthly spike; a launch-triggered batch is smoothed the
# same way.
class DescriptionRefreshJob < ApplicationJob
  queue_as :default

  # Mirrors OpenRouter::ModelSync::MAX_GENERATED_PER_RUN: enough to keep the
  # catalogue fresh (a few refreshes a day covers steady-state drift, with head
  # room for a launch that flags a provider's whole lineup at once) without a
  # single run firing hundreds of serial Anthropic calls.
  REFRESH_PER_RUN = 25

  def perform
    models = AiModel.due_for_description_refresh
                    .includes(:provider)
                    .limit(REFRESH_PER_RUN)
                    .to_a
    return Rails.logger.info("DescriptionRefreshJob: nothing stale, skipping") if models.empty?

    refreshed = 0
    models.each do |model|
      model.refresh_description
      refreshed += 1
    rescue => e
      # Isolate per model: one row's failure — a generation error, an SDK error
      # the operation didn't wrap, or a save failure — must not abort the rest of
      # the batch. The skipped row stays stale and is retried on a later run.
      Rails.logger.warn("DescriptionRefreshJob: #{e.class}: #{e.message} (model ##{model.id})")
      Honeybadger.notify(e) if defined?(Honeybadger)
    end

    Rails.logger.info("DescriptionRefreshJob: refreshed #{refreshed}/#{models.size} stale description(s)")
  end
end
