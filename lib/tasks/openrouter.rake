namespace :openrouter do
  desc "Pull the OpenRouter model catalogue and prices (the daily sync, on demand)"
  task sync: :environment do
    result = OpenRouter::ModelSync.call
    puts result
  end
end
