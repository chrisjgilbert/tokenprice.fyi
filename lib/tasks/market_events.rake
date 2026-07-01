namespace :market_events do
  desc "Generate the \"so what\" for published market events that don't have one yet"
  task backfill_insights: :environment do
    scope = MarketEvent.published.where(so_what: [ nil, "" ]).chronological
    total = scope.count
    puts "Backfilling the \"so what\" for #{total} market event(s)…"

    scope.each.with_index(1) do |event, i|
      event.generate_insight
      puts "  [#{i}/#{total}] #{event.title}"
    rescue MarketEvent::Insight::Error => e
      warn "  [#{i}/#{total}] #{event.title} — skipped: #{e.message}"
    end

    puts "Done."
  end
end
