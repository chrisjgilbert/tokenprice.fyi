require "test_helper"

class ModelCandidateTest < ActiveSupport::TestCase
  def candidate(**overrides)
    ModelCandidate.new({
      name: "Muse Spark 1.1", provider_name: "Meta", category_slug: "language",
      source_url: "https://ai.meta.com/blog/muse-spark", confidence: "M", status: "pending"
    }.merge(overrides))
  end

  test "derives a slug from the name on create" do
    c = candidate
    c.valid?
    assert_equal "muse-spark-1-1", c.slug
  end

  test "requires name, provider_name and a valid status" do
    assert_not candidate(name: nil).valid?
    assert_not candidate(provider_name: nil).valid?
    assert_not candidate(status: "bogus").valid?
    assert candidate.valid?
  end

  test "rejects a non-http source_url" do
    assert_not candidate(source_url: "javascript:alert(1)").valid?
    assert candidate(source_url: nil).valid?
  end

  test "existing_model finds a catalog row that would be duplicated" do
    assert_equal ai_models(:opus), candidate(name: "Claude Opus 4.8").tap(&:valid?).existing_model
    assert_nil candidate.existing_model
  end

  test "accept! on a per-token language candidate creates a manual model with a price point" do
    c = candidate(pricing: { "input" => 1.25, "output" => 4.25, "context_window" => 200_000 })
    c.save!

    model = assert_difference("AiModel.count", 1) { c.accept! }

    assert_equal "accepted", c.reload.status
    assert_equal "Muse Spark 1.1", model.name
    assert_equal "Meta", model.provider.name
    assert_equal AiModel::MANUAL_SOURCE, model.source
    assert_equal :text, model.modality_class
    assert_equal 1.25, model.current_input
    assert_equal 4.25, model.current_output
    assert_equal 200_000, model.context_window
  end

  test "accept! on a native-priced image candidate sets native pricing, no price point" do
    c = candidate(name: "Muse Image", category_slug: "image",
                  pricing: { "pricing_model" => "per_image", "price_summary" => "$0.03 / image" })
    c.save!

    model = c.accept!

    assert_equal :image_generation, model.modality_class
    assert model.native_priced?
    assert_empty model.price_points
    assert_equal "$0.03 / image", model.price_summary
    assert_equal Date.current, model.priced_as_of
    assert_includes AiModel.listed, model
  end

  test "accept! creates a novel provider when one doesn't exist yet" do
    c = candidate(provider_name: "Brand New Labs", pricing: { "input" => 1, "output" => 2 })
    c.save!

    assert_difference("Provider.count", 1) { c.accept! }
    assert Provider.find_by(slug: "brand-new-labs")
  end

  test "accept! is idempotent — a second accept returns the same row, no duplicate" do
    c = candidate(pricing: { "input" => 1, "output" => 2 })
    c.save!
    first = c.accept!

    assert_no_difference("AiModel.count") { assert_equal first, c.accept! }
  end

  test "a price-less launch is valid and accepts as an unpriced directory row" do
    c = candidate(name: "New Reranker", category_slug: "rerank", confidence: "L", pricing: {})
    c.save!
    assert_not c.priced?

    model = c.accept!
    assert_equal :rerank, model.modality_class
    assert model.directory_listing?, "an unpriced directory candidate becomes a 'not yet tracked' row"
  end

  test "dismiss! marks the candidate dismissed without creating a model" do
    c = candidate
    c.save!
    assert_no_difference("AiModel.count") { c.dismiss! }
    assert_equal "dismissed", c.reload.status
  end

  test "CATEGORY_SIGNATURE covers every model category, so accept! never mis-signs a row" do
    assert_equal ModelCategory.all.map(&:slug).sort, ModelCandidate::CATEGORY_SIGNATURE.keys.sort
  end

  test "a native-priced candidate never grows a stray per-token price point" do
    c = candidate(name: "Weird Image", category_slug: "image",
                  pricing: { "price_summary" => "$0.03 / image", "input" => 5 }) # stray input
    c.save!
    model = c.accept!
    assert_empty model.price_points, "native price stays in columns, no token point"
    assert model.native_priced?
  end

  test "seed_snippet renders a paste-ready db/seeds.rb hash" do
    c = candidate(name: "Muse Image", category_slug: "image",
                  pricing: { "pricing_model" => "per_image", "price_summary" => "$0.03 / image" })
    snippet = c.seed_snippet

    assert_includes snippet, "provider: :meta"
    assert_includes snippet, 'name: "Muse Image"'
    assert_includes snippet, 'output_modalities: ["image"]'
    assert_includes snippet, 'price_summary: "$0.03 / image"'
  end
end
