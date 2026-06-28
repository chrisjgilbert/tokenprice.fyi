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

      test "a price-less directory row reports null prices, never zero" do
        get api_v1_models_url(format: :json)
        models = JSON.parse(@response.body)["models"]

        forge = models.find { |m| m["slug"] == "pixel-forge-1" }
        assert forge, "the price-less image-gen directory row should be listed"
        assert_equal "image_generation", forge["modality_class"]
        assert_nil forge["price_per_mtok"]["input"]
        assert_nil forge["price_per_mtok"]["output"]
        assert_nil forge["price_per_mtok"]["cached_input"]
      end

      test "exposes the extra billed dimensions additively, null when absent" do
        get api_v1_models_url(format: :json)
        models = JSON.parse(@response.body)["models"]

        sonnet = models.find { |m| m["slug"] == "claude-sonnet-4-6" }
        assert_in_delta 3.75, sonnet["price_per_mtok"]["cache_write"], 0.0001
        assert_in_delta 40.0, sonnet["price_per_mtok"]["audio_input"], 0.0001
        assert_in_delta 0.002, sonnet["price_per_unit"]["image_input_usd"], 0.0001
        assert_in_delta 0.01, sonnet["price_per_unit"]["request_usd"], 0.0001

        # Existing per-mtok keys are untouched.
        assert_in_delta 3.0, sonnet["price_per_mtok"]["input"], 0.0001
        assert_in_delta 15.0, sonnet["price_per_mtok"]["output"], 0.0001
        assert_in_delta 0.3, sonnet["price_per_mtok"]["cached_input"], 0.0001

        # A model that isn't charged the extras reports them null.
        opus = models.find { |m| m["slug"] == "claude-opus-4-8" }
        assert_nil opus["price_per_mtok"]["cache_write"]
        assert_nil opus["price_per_mtok"]["audio_input"]
        assert_nil opus["price_per_unit"]["image_input_usd"]
        assert_nil opus["price_per_unit"]["request_usd"]
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
