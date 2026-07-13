class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  # A Slack incoming-webhook payload for a "N items awaiting review" nudge: a
  # fallback `text` line plus one mrkdwn section block. Shared by the curation
  # jobs (event + model) so the block skeleton and admin-link shape don't drift.
  def review_nudge(text:, detail:)
    { text:, blocks: [ { type: "section", text: { type: "mrkdwn", text: detail } } ] }
  end
end
