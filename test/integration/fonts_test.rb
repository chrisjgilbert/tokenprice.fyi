require "test_helper"

# The Google Fonts <link> must not block the critical render path (homepage LCP
# is H1 text waiting on it), and we only request the weights actually used in
# the design system so the WOFF2 transfer stays lean.
class FontsTest < ActionDispatch::IntegrationTest
  test "google fonts are loaded non-render-blocking with a noscript fallback" do
    get root_url
    assert_response :success

    # preconnect hints stay so the round trip starts early.
    assert_select "link[rel=preconnect][href='https://fonts.googleapis.com']", count: 1
    assert_select "link[rel=preconnect][href='https://fonts.gstatic.com'][crossorigin]", count: 1

    # The stylesheet is fetched without blocking render: print-media swap pattern,
    # flipped to all media once it loads.
    assert_select "link[rel=stylesheet][media=print][onload*='this.media=']" do |els|
      assert_equal 1, els.size
      assert_match %r{fonts\.googleapis\.com/css2}, els.first["href"]
    end

    # A plain-stylesheet fallback for no-JS clients.
    assert_select "noscript link[rel=stylesheet][href*='fonts.googleapis.com']", count: 1
  end

  test "the font request asks only for the weights the design system uses" do
    get root_url
    assert_response :success

    # Every weight in the request list must be genuinely used in app CSS (see the
    # grep in app/assets/tailwind/application.css). Both families use 400/500/600/700.
    href = css_select("link[media=print]").first["href"]
    assert_includes href, "Space+Grotesk:wght@400;500;600;700"
    assert_includes href, "JetBrains+Mono:wght@400;500;600;700"
    assert_includes href, "display=swap"
  end
end
