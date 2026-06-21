require "test_helper"

class GuideHelperTest < ActionView::TestCase
  # --- AUDIT #4: the takeaway must branch on the data, never render an empty
  # slot (no "()", no "****", no dangling "the capable-model step  ").

  test "takeaway names BOTH steps when cost-driver and capable-model differ" do
    # coding_agent: cost-driver = "edit / tool-call", capability = "plan".
    out = guide_takeaway(FeaturePattern.find("coding_agent"))

    assert_includes out, "edit / tool-call"
    assert_includes out, "plan"
    assert_includes out, "cost-driver step"
    assert_includes out, "capable-model step"
    assert_includes out, "different"
    refute_empty_slot out
  end

  test "takeaway collapses to one step when cost-driver and capable-model are the same" do
    # rag: generate answer is BOTH cost_driver and capability.
    out = guide_takeaway(FeaturePattern.find("rag"))

    assert_includes out, "generate answer"
    assert_includes out, "the same"
    # It must NOT claim the two are different when they're one step.
    refute_includes out, "They are different"
    refute_empty_slot out
  end

  test "takeaway branches to the no-capability copy when no step needs a capable model" do
    # summarization: a cost-driver step ("summarize") but NO capability step.
    pattern = FeaturePattern.find("summarization")
    assert pattern.steps.none?(&:capability?), "fixture precondition: no capability step"

    out = guide_takeaway(pattern)

    assert_includes out, "summarize"
    assert_match(/no step here needs a frontier model/i, out)
    # The bug #4 names: an empty capable-model slot must never render.
    refute_includes out, "capable-model step is"
    refute_empty_slot out
  end

  test "every pattern produces a takeaway with no empty-name artifact" do
    FeaturePattern.all.each do |pattern|
      out = guide_takeaway(pattern)
      assert out.present?, "#{pattern.key} produced a blank takeaway"
      refute_empty_slot out, "#{pattern.key} rendered an empty slot"
    end
  end

  # --- Per-task prose: distinct, present, plain.

  test "every pattern has a two-paragraph lede and three cost drivers" do
    FeaturePattern.all.each do |pattern|
      lede = guide_lede(pattern)
      drivers = guide_drivers(pattern)

      assert_equal 2, lede.size, "#{pattern.key} lede should be two paragraphs"
      assert lede.all?(&:present?), "#{pattern.key} has a blank lede paragraph"
      assert_equal 3, drivers.size, "#{pattern.key} should have three cost drivers"
      assert drivers.all?(&:present?), "#{pattern.key} has a blank cost driver"
    end
  end

  test "the six task ledes open distinctly (no repeated opening sentence)" do
    openings = FeaturePattern.all.map { |p| guide_lede(p).first.split(/(?<=\.)\s/).first }
    assert_equal openings.size, openings.uniq.size, "lede openings must be distinct: #{openings.inspect}"
  end

  private

  # No empty-name artifact: the broken renders #4 warns about.
  def refute_empty_slot(out, msg = nil)
    refute_includes out, "()", msg
    refute_includes out, "****", msg
    refute_match(/step is\s+[.,]/, out, msg) # "...step is ." with nothing in the slot
    refute_match(/step is\s+the same/, out, msg) # guards a same-step render with a missing name
  end
end
