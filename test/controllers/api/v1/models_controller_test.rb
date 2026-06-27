require "test_helper"

module Api
  module V1
    class ModelsControllerTest < ActionDispatch::IntegrationTest
      test "returns the catalog as JSON off PriceCatalog" do
        get api_v1_models_url(format: :json)
        assert_response :success
        assert_equal "application/json", @response.media_type

        body = JSON.parse(@response.body)
        assert_equal "USD per 1,000,000 tokens", body["unit"]
        assert_equal PriceCatalog.models.size, body["count"]

        opus = body["models"].find { |m| m["slug"] == "claude-opus-4-8" }
        assert_equal "Anthropic", opus["provider"]
        assert_equal "frontier", opus["tier"]
        assert_in_delta 5.0, opus["price_per_mtok"]["input"], 0.0001
        assert_in_delta 25.0, opus["price_per_mtok"]["output"], 0.0001
      end

      test "exposes modalities and the derived class additively" do
        get api_v1_models_url(format: :json)
        models = JSON.parse(@response.body)["models"]

        sonnet = models.find { |m| m["slug"] == "claude-sonnet-4-6" }
        assert_equal({ "input" => %w[text image], "output" => %w[text] }, sonnet["modalities"])
        assert_equal "multimodal", sonnet["modality_class"]

        # A model with no recorded signature classifies as text and reports its
        # (empty) recorded modality sets verbatim — the API doesn't synthesise them.
        deepseek = models.find { |m| m["slug"] == "deepseek-v4-pro" }
        assert_equal "text", deepseek["modality_class"]
        assert_equal([], deepseek["modalities"]["input"])
        assert_equal([], deepseek["modalities"]["output"])

        # Existing keys are untouched.
        assert_in_delta 5.0, models.find { |m| m["slug"] == "claude-opus-4-8" }["price_per_mtok"]["input"], 0.0001
      end

      test "is cross-origin readable" do
        get api_v1_models_url(format: :json)
        assert_equal "*", @response.headers["Access-Control-Allow-Origin"]
      end

      test "excludes retired and price-less models" do
        get api_v1_models_url(format: :json)
        slugs = JSON.parse(@response.body)["models"].map { |m| m["slug"] }
        refute_includes slugs, "claude-instant-1" # retired
        refute_includes slugs, "claude-no-price"  # no prices
      end
    end
  end
end
