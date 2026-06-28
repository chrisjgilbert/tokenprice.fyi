require "test_helper"

class GuideControllerTest < ActionDispatch::IntegrationTest
  test "index renders the task chooser with the deck H1 and every task linked" do
    get guide_path
    assert_response :success

    assert_select "h1", text: /Starting models, by task\./
    assert_select "header p", text: /Most AI features run as a chain of calls, each with a different job\./

    FeaturePattern.all.each do |pattern|
      assert_select "a[href=?]", guide_task_path(pattern.slug), text: /#{Regexp.escape(pattern.label)}/
    end
  end

  test "show resolves for a known task and shows its label" do
    get guide_task_path("rag")
    assert_response :success
    assert_select "h1", text: /#{Regexp.escape(FeaturePattern.find("rag").label)}/
  end

  test "show 404s for an unknown task" do
    get "/guide/nonsense"
    assert_response :not_found
  end

  # --- Slug hygiene: coding_agent ships as the hyphenated /guide/coding-agent.

  test "coding agent resolves at the hyphenated slug" do
    get "/guide/coding-agent"
    assert_response :success
    assert_select "h1", text: /#{Regexp.escape(FeaturePattern.find("coding_agent").label)}/
  end

  test "the legacy underscore slug 301s to the hyphenated URL" do
    get "/guide/coding_agent"
    assert_response :moved_permanently
    assert_redirected_to "/guide/coding-agent"
  end

  test "every task renders 200 (smoke)" do
    FeaturePattern.all.each do |pattern|
      get guide_task_path(pattern.slug)
      assert_response :success, "#{pattern.key} did not render"
    end
  end

  test "the summarization task heads with the US spelling" do
    get guide_task_path("summarization")
    assert_response :success
    assert_select "h1", text: /Summarization/
    assert_select "h1", text: /Summarisation/, count: 0
  end

  # --- AUDIT #3: each task page renders a unique deepened "how to choose" block.

  test "every task renders a how-to-choose heading and its unique block" do
    FeaturePattern.all.each do |pattern|
      get guide_task_path(pattern.slug)
      assert_response :success
      assert_select "h2", text: /How to choose for #{Regexp.escape(pattern.label)}/
    end
  end

  test "the coding agent how-to-choose block names both steps and the split" do
    get guide_task_path("coding-agent")
    assert_response :success
    body = @response.body
    # Task-specific strings from the deepened block.
    assert_match(/Put the capable model on plan/, body)
    assert_match(/cached input, not a bigger model/, body)
  end

  test "the rag how-to-choose block leads with retrieval precision" do
    get guide_task_path("rag")
    assert_response :success
    assert_match(/Spend on retrieval precision before you spend on a bigger model/, @response.body)
  end

  # --- AUDIT #3: the guide cross-links to the feature_costs cost breakdown.

  test "the guide cross-links to the full cost breakdown on feature_costs" do
    get guide_task_path("rag")
    assert_response :success
    assert_select "a[href=?]", "#{learn_feature_costs_path}#rag", text: /cost breakdown/i
  end

  # --- AUDIT #4: the takeaway branches on the data.

  test "summarization uses the no-capable-model takeaway with no empty-name artifact" do
    get guide_task_path("summarization")
    assert_response :success
    body = @response.body

    assert_match(/no step here needs a frontier model/i, body)
    # The exact bug #4 names — an empty capable-model slot.
    refute_includes body, "the capable-model step ()"
    refute_includes body, "****"
  end

  test "coding_agent names both a cost-driver step and a different capable-model step" do
    get guide_task_path("coding-agent")
    assert_response :success
    body = @response.body

    # cost-driver = edit / tool-call; capability = plan. Both must be named.
    assert_includes body, "edit / tool-call"
    assert_includes body, "plan"
    assert_match(/different/i, body)
  end

  # --- AUDIT #5: the RAG embed step is unpriced and labelled, never a fake $.

  test "rag embed step renders unpriced and labelled, with no fabricated dollar figure" do
    get guide_task_path("rag")
    assert_response :success
    body = @response.body

    # The embed step is present...
    assert_includes body, "embed query"
    # ...labelled as not priced here (separate embeddings endpoint)...
    assert_match(/not priced here/i, body)
    assert_match(/embeddings endpoint/i, body)

    # ...and carries no $-figure of its own. Isolate the embed step's markup and
    # assert it holds no dollar amount.
    embed_chunk = body[/embed query.*?(?=retrieve \/ rerank)/m]
    assert embed_chunk.present?, "could not isolate the embed step markup"
    refute_match(/\$\d/, embed_chunk, "the embed step must not show a fabricated dollar figure")
  end

  # --- Positive per-call cost renders for real (priced fixtures present).

  test "rag generate step renders a real per-call dollar figure for its priced options" do
    get guide_task_path("rag")
    assert_response :success
    body = @response.body

    # claude-haiku-4-5 and claude-sonnet-4-6 are priced fixtures; the generate
    # step prices them against its shape, so a $-prefixed per-call figure shows.
    assert_match(/\$\d/, body, "expected at least one real per-call dollar figure")
    assert_includes body, "per call"
  end

  # --- FU.2: options show the model DISPLAY NAME, not the raw slug.

  test "the generate step shows resolvable options by display name, linking by slug" do
    get guide_task_path("rag")
    assert_response :success
    body = @response.body

    # The fixtures claude-haiku-4-5 / claude-sonnet-4-6 carry display names.
    assert_includes body, "Guide Haiku Fixture"
    assert_includes body, "Guide Sonnet Fixture"
    # The link still routes by slug.
    assert_select "a[href=?]", model_path("claude-haiku-4-5")
    assert_select "a[href=?]", model_path("claude-sonnet-4-6")
    # The display name is the visible link text, not the raw slug.
    assert_select "a[href=?]", model_path("claude-haiku-4-5"), text: "Guide Haiku Fixture"
  end

  test "an unresolved option falls back to rendering its slug" do
    get guide_task_path("rag")
    assert_response :success
    # llama-4-maverick is not in fixtures → shown as its slug, no crash.
    assert_includes @response.body, "llama-4-maverick"
  end

  # --- Graceful "—" for an option whose slug isn't in the catalog.

  test "an unresolved option slug renders an em-dash, not an error" do
    # rag generate's open_weight option (llama-4-maverick) is not in fixtures,
    # so it must degrade to a dash rather than raising or fabricating a price.
    get guide_task_path("rag")
    assert_response :success
    assert_includes @response.body, "—"
  end

  # --- Phase 2: a price-less directory row in the catalog can't break the guide.

  test "every task still renders with a price-less directory row in the catalog" do
    # The image-gen fixture (no price points) rides in PriceCatalog.models; the
    # guide loads that catalog and prices its options against it. None of the
    # guide's option slugs reference the price-less row, so every page must still
    # render and never fabricate a $0 figure off the nil-priced entry.
    assert_includes PriceCatalog.models.map(&:slug), "pixel-forge-1"
    FeaturePattern.all.each do |pattern|
      get guide_task_path(pattern.slug)
      assert_response :success, "#{pattern.key} did not render with a price-less catalog row present"
    end
  end

  # --- SPEC §3: the guide's feature_costs cross-link lands on the MATCHING
  # feature_costs section when one exists, and falls back to the index otherwise.
  test "the guide deep-links to the matching feature_costs section for a known pattern" do
    get guide_task_path("rag")
    assert_response :success
    assert_select "a[href=?]", "#{learn_feature_costs_path}#rag"
  end

  test "the guide falls back to the plain feature_costs link for a pattern with no matching section" do
    get guide_task_path("agentic")
    assert_response :success
    # agentic has no dedicated feature_costs section, so the generic link stands.
    assert_select "a[href=?]", learn_feature_costs_path
  end
end
