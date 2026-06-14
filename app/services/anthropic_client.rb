require "anthropic"

# Builds an Anthropic::Client using the API key from encrypted credentials
# (anthropic_api_key), failing fast with a clear message when it is missing or
# blank.
#
# Reading from credentials keeps the key alongside the app's other runtime
# secrets (honeybadger_api_key, slack_webhook_url) and avoids a blank value
# being sent verbatim as the x-api-key header — which otherwise surfaces as a
# confusing 401 "invalid x-api-key" deep inside a job.
module AnthropicClient
  class MissingApiKeyError < StandardError; end

  def self.build
    key = Rails.application.credentials.anthropic_api_key
    if key.nil? || key.to_s.strip.empty?
      raise MissingApiKeyError,
            "anthropic_api_key credential is missing or blank — add it via `bin/rails credentials:edit`."
    end

    Anthropic::Client.new(api_key: key)
  end
end
