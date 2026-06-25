namespace :openrouter do
  desc "Pull the OpenRouter model catalogue and prices (the daily sync, on demand)"
  task sync: :environment do
    result = OpenRouter::ModelSync.call
    puts result
  end

  # One-off backfill: the daily sync only generates editorial copy for models
  # as they are first imported, so OpenRouter rows that predate that feature
  # still carry the (often truncated) upstream blurb and no editorial facets.
  # This walks those rows and writes them up the same way a fresh import would.
  # Set LIMIT to cap how many are processed in one run (handy for a cheap trial).
  desc "Generate editorial copy for existing OpenRouter models that lack it"
  task backfill_descriptions: :environment do
    generator = ModelDescriptionGenerator.new

    scope = AiModel.from_openrouter.includes(:provider).where(strengths: [ nil, "" ])
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
        source_text:    model.description.presence
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
end

