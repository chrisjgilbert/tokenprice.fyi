require "anthropic"

# Transport for the Anthropic API: builds a client from credentials, and runs
# the one call shape this app uses — a single forced-tool call that returns the
# tool's input hash.
#
# `build` reads the key from encrypted credentials (anthropic_api_key), failing
# fast with a clear message when it is missing or blank. Reading from
# credentials keeps the key alongside the app's other runtime secrets
# (honeybadger_api_key, slack_webhook_url) and avoids a blank value being sent
# verbatim as the x-api-key header — which otherwise surfaces as a confusing 401
# "invalid x-api-key" deep inside a job.
module AnthropicClient
  class MissingApiKeyError < StandardError; end
  class Error < StandardError; end

  def self.build
    key = Rails.application.credentials.anthropic_api_key
    if key.nil? || key.to_s.strip.empty?
      raise MissingApiKeyError,
            "anthropic_api_key credential is missing or blank — add it via `bin/rails credentials:edit`."
    end

    Anthropic::Client.new(api_key: key)
  end

  # Issue a single forced-tool call and return the tool's `input` hash. The model
  # is required to call `tool` (the one tool offered), so the response carries
  # exactly one tool_use block. Raises AnthropicClient::Error on an API failure
  # or a response with no tool_use block — callers wrap that in a domain error so
  # they can fall back rather than persist a half-written record.
  def self.tool_call(model:, system:, messages:, tool:, max_tokens:, client: nil)
    client ||= build
    response = client.messages.create(
      model:       model,
      max_tokens:  max_tokens,
      system_:     system,
      messages:    messages,
      tools:       [ tool ],
      tool_choice: { type: "tool", name: tool[:name] }
    )

    tool_use = response.content.find { |block| block.type == :tool_use }
    raise Error, "No tool_use block in response" unless tool_use

    tool_use.input
  rescue Anthropic::Errors::Error => e
    raise Error, "Anthropic API error: #{e.message}"
  end
end
