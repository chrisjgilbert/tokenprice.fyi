# The detection→curation bridge. Runs on a schedule, takes recent
# "release"-classified news_items (new-model launches the classifier already
# flagged), and asks Claude to extract a ModelCandidate from each — a proposed
# catalog row for a human to approve in the admin review queue. The twin of
# EventCurationJob (news → MarketEvent drafts), targeting AiModel instead.
#
# Nothing here publishes: a candidate is a draft. Dedup is layered — a launch
# already in the catalog, or already sitting as a pending candidate, produces
# nothing. Each item is stamped curated_for_model_at once processed so it's never
# re-mined; an item whose extraction hit a transport error is left unstamped so a
# later run retries it (bounded by LOOKBACK).
class ModelCurationJob < ApplicationJob
  queue_as :default

  # Wider than the run cadence so a missed run doesn't drop launches; the stamp
  # prevents re-processing regardless.
  LOOKBACK = 3.days

  def perform
    items = NewsItem.awaiting_model_curation
                    .where("published_at >= ? OR published_at IS NULL", LOOKBACK.ago)
                    .order(published_at: :desc)
                    .limit(50)
                    .to_a
    return Rails.logger.info("ModelCurationJob: no release items, skipping") if items.empty?

    created  = 0
    errored  = []

    items.each do |item|
      candidate = item.extract_model_candidate
      created += 1 if candidate && persist(candidate)
    rescue NewsItem::ModelExtraction::Error => e
      errored << item.id
      Rails.logger.warn("ModelCurationJob: extraction error for #{item.url} — #{e.message}")
    end

    # Stamp everything we processed cleanly (including items that yielded no
    # model); leave errored items unstamped so a later run retries them.
    NewsItem.where(id: items.map(&:id) - errored).update_all(curated_for_model_at: Time.current)

    SlackNotifier.post(slack_payload(created)) if created.positive?
    Rails.logger.info("ModelCurationJob: #{created} candidate(s) from #{items.size} item(s)")
  end

  private

  # Save the candidate unless it duplicates a catalog row or a pending candidate.
  def persist(candidate)
    return false if candidate.existing_model
    return false if ModelCandidate.pending.exists?(slug: candidate.effective_slug)

    candidate.save!
    true
  end

  def slack_payload(count)
    review_link = "<https://tokenprice.fyi/admin/model_candidates|Review queue>"
    plural = "s" if count != 1
    { text: "ModelCurationJob found #{count} model candidate#{plural}",
      blocks: [
        { type: "section",
          text: { type: "mrkdwn",
                  text: "*🆕 #{count} model candidate#{plural} awaiting review*\n" \
                        "#{review_link} — approve (creates the row) or dismiss each in the admin." } }
      ] }
  end
end
