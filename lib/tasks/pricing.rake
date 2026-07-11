namespace :pricing do
  # Curated prices (source: manual) have no automated sync, unlike the
  # OpenRouter-synced language rows, so they drift as providers reprice. This
  # reports each curated listed model's price age by category, flagging rows past
  # the staleness threshold (DAYS, default 90) and directory rows still awaiting a
  # price — so a maintenance pass knows what to re-verify against the
  # docs/*_MODEL_PRICING.md datasets. Read-only; logic lives in PricingStaleness.
  desc "Report curated price freshness by category, flagging stale rows (DAYS=90)"
  task staleness: :environment do
    days = Integer(ENV.fetch("DAYS", PricingStaleness::DEFAULT_STALE_AFTER_DAYS.to_s))
    groups = PricingStaleness.report(days:)

    groups.each do |group|
      puts "\n#{group.category.label} — #{group.rows.size} curated, " \
           "#{group.stale_count} stale, #{group.undated_count} undated, #{group.unpriced_count} unpriced"
      group.rows.each do |row|
        marker, note =
          if row.unpriced?   then [ "  ·", "unpriced — awaiting a price" ]
          elsif row.undated? then [ "  ?", "priced, but no priced_as_of date — add one" ]
          elsif row.stale?   then [ "  ⚠", "#{row.age_days}d old — priced #{row.priced_on} (STALE)" ]
          else [ "  ✓", "#{row.age_days}d old — priced #{row.priced_on}" ]
          end
        puts "#{marker} #{row.slug.ljust(32)} #{note}"
      end
    end

    totals = PricingStaleness.totals(groups)
    puts "\n#{totals[:curated]} curated prices: #{totals[:stale]} stale (> #{days}d), " \
         "#{totals[:undated]} undated, #{totals[:unpriced]} unpriced."
    puts "Re-verify flagged rows against docs/*_MODEL_PRICING.md, update the figure and " \
         "priced_as_of in db/seeds.rb, then run bin/rails db:seed."
  end
end
