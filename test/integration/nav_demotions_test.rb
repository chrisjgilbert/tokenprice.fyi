require "test_helper"

class NavDemotionsTest < ActionDispatch::IntegrationTest
  test "primary nav no longer carries a Compare tab" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", compare_path, false,
      "Compare should be demoted out of the primary nav"
  end

  test "primary nav still carries Models and Trends" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", root_path
    assert_select "nav.tp-nav a[href=?]", trends_path
  end

  test "primary nav now carries a Guide tab" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", guide_path
  end

  test "compare still serves as a generated view" do
    get compare_path
    assert_response :success
  end

  test "provider page still serves as a generated view" do
    get provider_path(providers(:anthropic))
    assert_response :success
  end
end
