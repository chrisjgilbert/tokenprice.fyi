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

  test "country_code is normalised to upper-case and must be two letters" do
    provider = Provider.create!(name: "Cohere", country_code: "ca")
    assert_equal "CA", provider.country_code

    assert Provider.new(name: "A", country_code: "").valid?
    assert_not Provider.new(name: "B", country_code: "USA").valid?
    assert_not Provider.new(name: "C", country_code: "1").valid?
  end

  test "flag_emoji builds a flag from the country code" do
    assert_equal "🇺🇸", Provider.new(country_code: "US").flag_emoji
    assert_equal "🇨🇳", Provider.new(country_code: "cn").flag_emoji
    assert_nil Provider.new(country_code: "").flag_emoji
  end
end
