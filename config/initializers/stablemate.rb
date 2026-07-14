Stablemate.configure do |c|
  c.api_key = Rails.application.credentials.dig(:stablemate, :api_key)
  c.logger  = Rails.logger
end
