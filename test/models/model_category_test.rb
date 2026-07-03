require "test_helper"

class ModelCategoryTest < ActiveSupport::TestCase
  test "for resolves the known params" do
    assert_equal "language", ModelCategory.for("language").slug
    assert_equal "image", ModelCategory.for("image").slug
  end

  test "for falls back to the language default for nil, blank, or unknown params" do
    assert_equal ModelCategory.default, ModelCategory.for(nil)
    assert_equal ModelCategory.default, ModelCategory.for("")
    assert_equal ModelCategory.default, ModelCategory.for("nonsense")
    assert_equal "language", ModelCategory.default.slug
  end

  test "all is the ordered tab strip, language first" do
    assert_equal %w[language image], ModelCategory.all.map(&:slug)
  end

  test "member? splits image generation from every other class" do
    image = ModelCategory.for("image")
    language = ModelCategory.for("language")

    assert image.member?(:image_generation)
    refute image.member?(:text)
    refute image.member?(:multimodal)

    refute language.member?(:image_generation)
    assert language.member?(:text)
    assert language.member?(:multimodal)
    assert language.member?(:embedding)
    assert language.member?(:any_to_any)
  end

  test "member? accepts a string as well as a symbol" do
    assert ModelCategory.for("image").member?("image_generation")
    assert ModelCategory.for("language").member?("text")
  end

  test "each category exposes sorts, a default sort within them, a direction, and SEO copy" do
    ModelCategory.all.each do |category|
      assert category.sorts.any?, "#{category.slug} should offer at least one sort"
      assert_includes category.sorts, category.default_sort
      assert_includes %w[asc desc], category.default_dir
      assert category.title.present?
      assert category.meta_description.present?
      assert category.param.present?
      assert category.path_name.present?
    end
  end

  test "language sorts allow the token-price keys; image sorts do not" do
    language = ModelCategory.for("language")
    image = ModelCategory.for("image")

    assert_includes language.sorts, "input"
    assert_includes language.sorts, "output"
    assert_equal "output", language.default_sort
    assert_equal "desc", language.default_dir

    refute_includes image.sorts, "input"
    refute_includes image.sorts, "output"
    assert_includes image.sorts, "released"
    assert_equal "name", image.default_sort
    assert_equal "asc", image.default_dir
  end
end
