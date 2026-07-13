require "test_helper"

class NavStructureTest < ActionDispatch::IntegrationTest
  test "primary nav no longer carries Compare" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", compare_path, count: 0
  end

  test "primary nav no longer carries the retired News tab" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href='/news']", count: 0
  end

  test "primary nav carries Models and Events, not the retired Trends" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", root_path
    assert_select "nav.tp-nav a[href=?]", events_path
    assert_select "nav.tp-nav a[href='/trends']", count: 0
  end

  test "the footer preserves a crawlable Compare link" do
    get root_path
    assert_response :success
    assert_select "footer.tp-foot a[href=?]", compare_path
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
