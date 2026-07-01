class RemoveFeaturedFromAiModels < ActiveRecord::Migration[8.1]
  def change
    # The hero switched from a single one-per-kind pick to a multi-event
    # mini-timeline (EventsHelper#hero_events), which no longer needs to
    # decide a "winner" between same-day launches — so the curated override
    # this column existed for is gone too.
    remove_column :ai_models, :featured, :boolean, default: false, null: false
  end
end
