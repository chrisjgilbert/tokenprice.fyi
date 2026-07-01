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
  class Error < StandardError; end
  # A subclass of Error (not a sibling) so every caller's existing
  # `rescue AnthropicClient::Error` already catches this without also having
  # to name it explicitly — the callers all treat "the key is missing" the
  # same as any other transport failure.
  class MissingApiKeyError < Error; end

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

  WEB_SEARCH_TOOL = { type: "web_search_20260209", name: "web_search" }.freeze

  HTTP_URL = %r{\Ahttps?://\S+\z}i

  # Run a web-search-grounded generation and return the model's prose plus the
  # sources it cited: { text:, citations: } where citations is an array of
  # { "url" =>, "title" => } hashes (string keys, so they survive a round-trip
  # through a JSON column unchanged), deduped by url and limited to http(s) links
  # so a stored value can't smuggle a javascript:/data: scheme into a link.
  #
  # The web search tool runs a server-side loop; when it reaches its per-turn
  # cap the response comes back with stop_reason :pause_turn and must be re-sent
  # to resume (no extra user message — the server picks up from the trailing
  # server_tool_use). We accumulate text and citations across those turns and
  # bound the resumes with max_continuations so a stuck loop can't run forever.
  def self.search_call(model:, system:, messages:, max_tokens:, max_searches: 5, max_continuations: 4, client: nil)
    client ||= build
    tool = WEB_SEARCH_TOOL.merge(max_uses: max_searches)

    convo     = messages.dup
    text      = +""
    citations = []

    # One initial request plus up to max_continuations resumes; the iteration
    # count is the bound, so a stuck pause_turn loop can't run forever.
    (max_continuations + 1).times do
      response = client.messages.create(
        model:      model,
        max_tokens: max_tokens,
        system_:    system,
        messages:   convo,
        tools:      [ tool ]
      )

      response.content.each do |block|
        next unless block.type == :text

        text << block.text.to_s
        Array(block.citations).each do |citation|
          url = citation.url.to_s
          next unless url.match?(HTTP_URL)

          citations << { "url" => url, "title" => citation.title.to_s.presence }
        end
      end

      convo += [ { role: "assistant", content: response.content } ]

      break unless response.stop_reason == :pause_turn
    end

    { text: text.strip, citations: citations.uniq { |c| c["url"] } }
  rescue Anthropic::Errors::Error => e
    raise Error, "Anthropic API error: #{e.message}"
  end
end
