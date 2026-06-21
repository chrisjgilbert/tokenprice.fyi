require "test_helper"

# The static 404 page is served by the web server (no Rails), so it must be
# self-contained. It carries the brand and routes the visitor back into the site.
class Branded404Test < ActionDispatch::IntegrationTest
  def page
    File.read(Rails.root.join("public/404.html"))
  end

  test "404 carries the tokenprice.fyi wordmark" do
    assert_match(/tokenprice/, page)
    assert_match(/\.fyi/, page)
  end

  test "404 links back to the homepage and the guide" do
    body = page
    assert_match %r{href="/"}, body, "expected a link back to the homepage"
    assert_match %r{href="/guide"}, body, "expected a link to the guide"
  end

  test "404 is noindexed and self-contained (no asset-pipeline deps)" do
    body = page
    assert_match(/noindex/, body)
    # Served statically: no fingerprinted assets or external stylesheets.
    refute_match(/stylesheet_link_tag|data-turbo-track|fonts\.googleapis/, body)
  end
end
