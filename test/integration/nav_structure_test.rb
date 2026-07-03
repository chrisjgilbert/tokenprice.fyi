require "test_helper"

class NavStructureTest < ActionDispatch::IntegrationTest
  test "primary nav carries a Compare tab" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", compare_path
  end

  test "primary nav still carries Models and Events" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", root_path
    assert_select "nav.tp-nav a[href=?]", events_path
  end

  test "primary nav now carries a Trends tab" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", trends_path
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
