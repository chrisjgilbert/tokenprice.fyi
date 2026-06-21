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

    assert_includes out, "summarise"
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

  # --- The deepened "how to choose" block: unique editorial per task, grounded
  # in that task's real pipeline (the steps, the cost-driver vs capable-model
  # distinction). Not boilerplate.

  test "every pattern has a non-empty how-to-choose block that names its cost-driver step" do
    FeaturePattern.all.each do |pattern|
      prose = guide_choosing(pattern)
      assert prose.present?, "#{pattern.key} produced a blank how-to-choose block"
      driver = pattern.cost_driver_step
      assert_includes prose, driver.role, "#{pattern.key} block should name its cost-driver step" if driver
    end
  end

  test "the how-to-choose blocks are unique editorial per task, not boilerplate" do
    blocks = FeaturePattern.all.map { |p| guide_choosing(p) }
    assert_equal blocks.size, blocks.uniq.size, "how-to-choose blocks must differ per task"
  end

  test "a task with a distinct capable-model step names it in the how-to-choose block" do
    # coding_agent: capable-model step = "plan", a different step from the driver.
    prose = guide_choosing(FeaturePattern.find("coding_agent"))
    assert_includes prose, "plan"
    assert_includes prose, "capable-model step"
  end

  test "the no-capability task does not claim a capable-model step in the block" do
    # summarization: no capability step, so the block must not assert one.
    prose = guide_choosing(FeaturePattern.find("summarization"))
    assert_match(/no step here needs a frontier model/i, prose)
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
