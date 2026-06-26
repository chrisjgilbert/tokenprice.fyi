require "net/http"
require "json"

module OpenRouter
  # Thin read-only wrapper around the public OpenRouter REST API.
  #
  # The models catalogue (GET /api/v1/models) needs no authentication, but an
  # API key is sent when OPENROUTER_API_KEY is present so the same client can
  # reach authenticated endpoints later.
  #
  #   OpenRouter::Client.new.models  # => [{ "id" => "anthropic/...", ... }, ...]
  class Client
    Error = Class.new(StandardError)

    BASE_URL        = "https://openrouter.ai/api/v1".freeze
    DEFAULT_TIMEOUT = 30

    def initialize(api_key: ENV["OPENROUTER_API_KEY"], base_url: BASE_URL, timeout: DEFAULT_TIMEOUT)
      @api_key  = api_key
      @base_url = base_url
      @timeout  = timeout
    end

    # The full list of models OpenRouter exposes, as parsed hashes straight from
    # the API. Raises Error on a transport failure or an unexpected payload.
    def models
      body = request_json("/models")
      data = body["data"]
      raise Error, "expected a 'data' array, got #{data.class}" unless data.is_a?(Array)

      data
    end

    private

    def request_json(path)
      uri  = URI.join("#{@base_url}/", path.delete_prefix("/"))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout

      request = Net::HTTP::Get.new(uri)
      request["Accept"]        = "application/json"
      request["Authorization"] = "Bearer #{@api_key}" if @api_key.present?

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "GET #{path} failed: #{response.code} #{response.message}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      raise Error, "GET #{path} returned invalid JSON: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout, IOError, SocketError, SystemCallError => e
      raise Error, "GET #{path} connection error: #{e.class}: #{e.message}"
    end
  end
end
