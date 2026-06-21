require "test_helper"

# Invariant tests for the FeaturePattern registry — the single source of truth
# the Guide and the anatomy explainer both render from. These assert the *shape*
# and the editorial invariants (cost_driver ≠ capability mismatch, the
# no-capability summarization case, the unpriced RAG embed step), not the DB.
# Resolving slugs against the live catalog is a later task.
class FeaturePatternTest < ActiveSupport::TestCase
  TIERS = %w[small mid frontier].freeze
  EXPECTED_KEYS = %w[rag coding_agent chatbot classification summarization agentic].freeze
  SLUG_RE = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  test "all six launch keys are present and ordered" do
    assert_equal EXPECTED_KEYS, FeaturePattern.all.map(&:key)
  end

  test "find returns the matching pattern" do
    EXPECTED_KEYS.each do |k|
      pattern = FeaturePattern.find(k)
      assert_not_nil pattern, "expected to find #{k}"
      assert_equal k, pattern.key
    end
  end

  test "find returns nil for an unknown key" do
    assert_nil FeaturePattern.find("does-not-exist")
    assert_nil FeaturePattern.find(nil)
  end

  # --- Public slug: underscores in the key become hyphens for the URL, while
  # the internal key keeps its underscore.

  test "slug hyphenates the underscored key but every slug is well-formed" do
    coding = FeaturePattern.find("coding_agent")
    assert_equal "coding-agent", coding.slug
    assert_equal "coding_agent", coding.key

    FeaturePattern.all.each do |p|
      assert_match SLUG_RE, p.slug, "#{p.key} slug not well-formed: #{p.slug.inspect}"
      assert_not_includes p.slug, "_", "#{p.key} slug must not contain an underscore"
    end
  end

  test "find resolves a hyphenated slug back to the underscored key" do
    assert_equal "coding_agent", FeaturePattern.find("coding-agent").key
    # The underscored key still resolves (used internally and by the legacy URL).
    assert_equal "coding_agent", FeaturePattern.find("coding_agent").key
  end

  test "every pattern has a label, blurb and at least one step" do
    FeaturePattern.all.each do |p|
      assert p.label.present?, "#{p.key} missing label"
      assert p.blurb.present?, "#{p.key} missing blurb"
      assert p.steps.any?, "#{p.key} has no steps"
    end
  end

  test "every step has a valid tier" do
    each_step do |p, s|
      assert_includes TIERS, s.tier, "#{p.key}/#{s.role} bad tier #{s.tier.inspect}"
    end
  end

  test "every step shape has positive integer sys/in/out" do
    each_step do |p, s|
      %i[sys in out].each do |dim|
        v = s.shape[dim]
        assert_kind_of Integer, v, "#{p.key}/#{s.role} shape #{dim} not Integer"
        assert v.positive?, "#{p.key}/#{s.role} shape #{dim} not positive (#{v})"
      end
    end
  end

  test "every step has options with at least one non-nil slug" do
    each_step do |p, s|
      present = s.options.values.compact
      assert present.any?, "#{p.key}/#{s.role} has no option slugs"
    end
  end

  test "every option slug is a well-formed slug string" do
    each_step do |p, s|
      s.options.each_value do |slug|
        next if slug.nil?

        assert_kind_of String, slug
        assert_match SLUG_RE, slug, "#{p.key}/#{s.role} bad slug #{slug.inspect}"
      end
    end
  end

  test "every step has a boolean priced flag" do
    each_step do |p, s|
      assert_includes [ true, false ], s.priced, "#{p.key}/#{s.role} priced not boolean"
    end
  end

  test "at least one pattern puts cost_driver and capability on different steps" do
    mismatched = FeaturePattern.all.select do |p|
      driver = p.steps.find(&:cost_driver?)
      capable = p.steps.find(&:capability?)
      driver && capable && !driver.equal?(capable)
    end
    assert mismatched.any?,
      "the cost_driver ≠ capability mismatch is the whole point — no pattern modeled it"
  end

  test "summarization has a cost_driver step and zero capability steps (audit #4)" do
    p = FeaturePattern.find("summarization")
    assert p.steps.any?(&:cost_driver?), "summarization needs a cost_driver step"
    assert_equal 0, p.steps.count(&:capability?),
      "summarization must have NO capability step (the no-capability case must be representable)"
  end

  test "the agentic pattern loops, with its cost driver on a small-tier step and capability elsewhere and more capable (audit)" do
    p = FeaturePattern.find("agentic")
    assert p.steps.any?(&:loops?), "agentic needs a looping step"

    driver = p.steps.find(&:cost_driver?)
    capable = p.steps.find(&:capability?)
    assert driver, "agentic needs a cost_driver step"
    assert capable, "agentic needs a capability step"
    assert_not driver.equal?(capable), "agentic driver and capability must be different steps"
    assert_equal "small", driver.tier, "agentic cost driver should sit on a small-tier step"
    assert_operator tier_rank(capable.tier), :>, tier_rank(driver.tier),
      "agentic capability step should be more capable than the cost driver"
  end

  test "the coding agent has a looping step" do
    assert FeaturePattern.find("coding_agent").steps.any?(&:loops?)
  end

  test "RAG has an unpriced embed/plumbing step (audit #5: embeddings are not a chat completion)" do
    p = FeaturePattern.find("rag")
    unpriced = p.steps.reject(&:priced?)
    assert unpriced.any?, "RAG must carry an unpriced embed/retrieve step"
    assert unpriced.all? { |s| s.cost_driver == false },
      "an unpriced plumbing step must not be flagged as a priced cost driver"
  end

  test "only the RAG pattern carries an unpriced step (no stray unpriced steps)" do
    FeaturePattern.all.each do |p|
      next if p.key == "rag"

      assert p.steps.all?(&:priced?), "#{p.key} unexpectedly has an unpriced step"
    end
  end

  # --- driver/capable relationship query methods (single source for the
  # guide takeaway and the anatomy reading) ---

  test "cost_driver_step returns the first step flagged cost_driver, or nil" do
    rag = FeaturePattern.find("rag")
    assert_equal "generate answer", rag.cost_driver_step.role

    agentic = FeaturePattern.find("agentic")
    assert_equal "subagent search", agentic.cost_driver_step.role
  end

  test "capable_step returns the first step flagged capability, or nil" do
    coding = FeaturePattern.find("coding_agent")
    assert_equal "plan", coding.capable_step.role

    summ = FeaturePattern.find("summarization")
    assert_nil summ.capable_step
  end

  test "driver_and_capable_relationship is :same when one step is both" do
    %w[rag chatbot].each do |key|
      assert_equal :same, FeaturePattern.find(key).driver_and_capable_relationship,
        "#{key} should read as :same"
    end
  end

  test "driver_and_capable_relationship is :different when they are distinct steps" do
    %w[coding_agent agentic].each do |key|
      assert_equal :different, FeaturePattern.find(key).driver_and_capable_relationship,
        "#{key} should read as :different"
    end
  end

  test "driver_and_capable_relationship is :no_capability when no step needs a capable model" do
    %w[summarization classification].each do |key|
      assert_equal :no_capability, FeaturePattern.find(key).driver_and_capable_relationship,
        "#{key} should read as :no_capability"
    end
  end

  private

  def each_step
    FeaturePattern.all.each do |p|
      p.steps.each { |s| yield p, s }
    end
  end

  def tier_rank(t) = TIERS.index(t)
end
