namespace :openrouter do
  desc "Pull the OpenRouter model catalogue and prices (the daily sync, on demand)"
  task sync: :environment do
    result = OpenRouter::ModelSync.call
    puts result
  end

  # One-off backfill / repair. Targets OpenRouter rows that still need a write-up:
  #   - no editorial facets yet (predate the generation feature), or
  #   - a description that is still the upstream blurb, which OpenRouter often
  #     truncates with a trailing ellipsis. The latter repairs models whose
  #     generated description was reverted by the enrich-clobber bug.
  # Generated descriptions never end in an ellipsis, so they aren't re-selected.
  # Set LIMIT to cap how many are processed in one run (handy for a cheap trial).
  desc "Generate or repair editorial copy for OpenRouter models that need it"
  task backfill_descriptions: :environment do
    generator = AiModel::Description.new

    missing   = AiModel.from_openrouter.where(strengths: [ nil, "" ])
    truncated = AiModel.from_openrouter.where("description LIKE ? OR description LIKE ?", "%…", "%...")
    scope = missing.or(truncated).includes(:provider)
    scope = scope.limit(Integer(ENV["LIMIT"])) if ENV["LIMIT"].present?
    models = scope.to_a

    puts "Backfilling editorial copy for #{models.size} OpenRouter model(s)…"
    updated = 0
    failed  = 0

    models.each do |model|
      copy = generator.generate(
        name:           model.name,
        provider:       model.provider.name,
        context_window: model.context_window,
        source_text:    model.description.presence,
        lineup:         model.sibling_lineup
      )
      next if copy.blank?

      model.update!(
        description: copy[:description].presence || model.description,
        strengths:   copy[:strengths],
        best_for:    copy[:best_for],
        limitations: copy[:limitations]
      )
      updated += 1
      puts "  ✓ #{model.slug}"
    rescue => e
      failed += 1
      warn "  ✗ #{model.slug} — #{e.class}: #{e.message}"
    end

    puts "Done: #{updated} updated, #{failed} failed."
  end

  # On-demand refresh of stale editorial copy — the same work DescriptionRefreshJob
  # does nightly, run now and uncapped for a one-off sweep (e.g. after tuning the
  # prompt or STALE_AFTER). Covers any listed row with generated copy (OpenRouter
  # or approved-candidate); hand-written seed editorial (no generation stamp) is
  # left alone. Set LIMIT to cap a trial run.
  desc "Refresh stale editorial copy for models that are due one"
  task refresh_descriptions: :environment do
    scope = AiModel.listed.description_stale
                   .stalest_description_first.includes(:provider)
    scope = scope.limit(Integer(ENV["LIMIT"])) if ENV["LIMIT"].present?
    models = scope.to_a

    puts "Refreshing #{models.size} stale description(s)…"
    refreshed = 0
    failed    = 0

    models.each do |model|
      model.refresh_description
      refreshed += 1
      puts "  ✓ #{model.slug}"
    rescue => e
      failed += 1
      warn "  ✗ #{model.slug} — #{e.class}: #{e.message}"
    end

    puts "Done: #{refreshed} refreshed, #{failed} failed."
  end
end
