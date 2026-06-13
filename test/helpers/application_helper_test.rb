require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "status_badge renders nothing for active models" do
    assert_nil status_badge("active")
  end

  test "status_badge tags suspended models with the suspended class" do
    badge = status_badge("suspended")
    assert_includes badge, "tp-status-suspended"
    assert_includes badge, "suspended"
  end

  test "status_badge tags legacy and retired models" do
    assert_includes status_badge("legacy"), "tp-status-legacy"
    assert_includes status_badge("retired"), "tp-status-retired"
  end
end
