require "test_helper"

class NavStructureTest < ActionDispatch::IntegrationTest
  test "primary nav no longer carries Compare" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", compare_path, count: 0
  end

  test "primary nav carries a News tab" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", news_path
  end

  test "primary nav still carries Models, Trends and Events" do
    get root_path
    assert_response :success
    assert_select "nav.tp-nav a[href=?]", root_path
    assert_select "nav.tp-nav a[href=?]", trends_path
    assert_select "nav.tp-nav a[href=?]", events_path
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
