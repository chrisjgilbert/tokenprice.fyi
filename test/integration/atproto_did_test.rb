require "test_helper"

class AtprotoDidTest < ActionDispatch::IntegrationTest
  test "serves the BlueSky DID as plain text for handle verification" do
    get "/.well-known/atproto-did"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal PagesController::BLUESKY_DID, response.body
    # AT Protocol resolves the handle by reading exactly the DID — a trailing
    # newline or markup would break verification.
    assert_match(/\Adid:plc:[a-z0-9]+\z/, response.body)
  end
end
