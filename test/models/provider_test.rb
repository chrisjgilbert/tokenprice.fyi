require "test_helper"

class ProviderTest < ActiveSupport::TestCase
  test "auto-generates a slug from the name" do
    assert_equal "cohere-ai", Provider.create!(name: "Cohere AI").slug
  end

  test "accent must be a hex colour when present" do
    assert Provider.new(name: "A", accent: "#4f46e5").valid?
    assert Provider.new(name: "B", accent: "#fff").valid?
    assert Provider.new(name: "C", accent: "").valid?
    assert_not Provider.new(name: "D", accent: "blue").valid?
    assert_not Provider.new(name: "E", accent: "4f46e5").valid?
  end
end
