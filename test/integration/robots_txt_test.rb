require "test_helper"

class RobotsTxtTest < ActiveSupport::TestCase
  ROBOTS = Rails.root.join("public/robots.txt")

  test "robots.txt disallows the health check endpoint and allows the API" do
    body = File.read(ROBOTS)
    assert_match(/^Disallow: \/up$/, body)
    # /api is intentionally allowed — it's the citation/backlink flywheel for AI crawlers.
    assert_no_match(/^Disallow: \/api$/, body)
  end

  test "robots.txt keeps the existing allow, admin disallow and sitemap lines" do
    body = File.read(ROBOTS)
    assert_match(/^Allow: \/$/, body)
    assert_match(/^Disallow: \/admin$/, body)
    assert_match(%r{^Sitemap: https://tokenprice\.fyi/sitemap\.xml$}, body)
  end
end
