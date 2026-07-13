# Rewrites stale editorial copy. Descriptions are generated once and then frozen,
# so they drift as models mature and as newer siblings reframe them; this job
# regenerates the ones AiModel.description_stale flags (age, or a newer
# same-provider release) on a rolling daily cadence.
#
# Scoped to `from_openrouter`: curated rows are hand-maintained and must never be
# overwritten by generated copy. Capped per run and non-fatal per model — a flaky
# API call is logged, not raised, so it doesn't poison the queue, and the row it
# skipped is still stale and picked up on a later run. The cap plus the daily
# schedule drains the whole catalogue well within the STALE_AFTER window rather
# than firing a monthly spike; a launch-triggered batch is smoothed the same way.
class DescriptionRefreshJob < ApplicationJob
  queue_as :default

  # Mirrors OpenRouter::ModelSync::MAX_GENERATED_PER_RUN: enough to keep the
  # catalogue fresh (a few refreshes a day covers steady-state drift, with head
  # room for a launch that flags a provider's whole lineup at once) without a
  # single run firing hundreds of serial Anthropic calls.
  REFRESH_PER_RUN = 25

  def perform
    models = AiModel.from_openrouter.listed.description_stale
                    .stalest_description_first
                    .includes(:provider)
                    .limit(REFRESH_PER_RUN)
                    .to_a
    return Rails.logger.info("DescriptionRefreshJob: nothing stale, skipping") if models.empty?

    refreshed = 0
    models.each do |model|
      model.refresh_description
      refreshed += 1
    rescue AiModel::Description::GenerateError => e
      Rails.logger.warn("DescriptionRefreshJob: #{e.message} (model ##{model.id})")
      Honeybadger.notify(e) if defined?(Honeybadger)
    end

    Rails.logger.info("DescriptionRefreshJob: refreshed #{refreshed}/#{models.size} stale description(s)")
  end
end
