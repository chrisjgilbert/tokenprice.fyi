Honeybadger.configure do |config|
  if (api_key = Rails.application.credentials.honeybadger_api_key)
    config.api_key = api_key
  end
end
