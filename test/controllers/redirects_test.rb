require "test_helper"

class RedirectsTest < ActionDispatch::IntegrationTest
  # The public /news feed was retired (no traffic); its curated distillation
  # lives at /events, so inbound links and bookmarks 301 there.
  test "/news permanently redirects to the events timeline" do
    get "/news"
    assert_response :moved_permanently
    assert_redirected_to "/events"
  end

  test "a paginated /news link also lands on the events timeline" do
    get "/news?page=3"
    assert_response :moved_permanently
    assert_redirected_to "/events"
  end
end
