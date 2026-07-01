# GuideHelper — the per-task prose and the computed takeaway for the Guide show
# page. Two reasons it lives here rather than in ERB:
#
#   * the ledes/drivers are editorial copy keyed by pattern.key — a hash is
#     cleaner and unit-testable (see test/helpers/guide_helper_test.rb);
#   * the takeaway must BRANCH on the data (AUDIT #4) — cost-driver and
#     capable-model are often different steps, sometimes the same step, and
#     sometimes there is no capable-model step at all. The branching builds off
#     the step objects, never a hardcoded per-task string, so it can never grow
#     an empty-name slot ("the capable-model step () …", the bug #4 names).
#
# House style (docs/MODEL_GUIDE_COPY.md): "the guide" lowercase; "per call" the
# only cost unit; canonical paired terms "cost-driver step" / "capable-model
# step"; "a feature is a chain of calls"; name the step, not a euphemism; tier
# ladder small / mid / frontier; no drama em-dashes; no "=" in prose; no
# rhetorical questions.
module GuideHelper
  # The label for each starting-option role, keyed by the `kind` a
  # FeaturePattern::Cost::Result carries — so the view names options from data,
  # never from array position.
  OPTION_KIND_LABELS = {
    cheap: "cheap default", quality: "step-up for quality", open_weight: "open-weight option"
  }.freeze

  def guide_option_label(kind) = OPTION_KIND_LABELS.fetch(kind, "option")

  # Defines every badge shown on a pipeline step (the tier ladder plus the
  # three flags) so a reader arriving straight from search — with no prior
  # context on the site's terms — has the meaning one click away instead of
  # guessing from an unexplained pill. Reuses tier_legend_entries (Application
  # Helper) so the tier wording has one home across the price table and here.
  def guide_badge_legend_entries
    tier_legend_entries + [
      [ "Repeats", "This step runs more than once per task, so its per-call cost bills again on every pass." ],
      [ "Cost-driver step", "The step that contributes the most to this task's per-call cost." ],
      [ "Capable-model step", "The step that needs a more capable, pricier model; the rest can run on something cheaper." ]
    ]
  end

  # Pattern keys with a worked section in the feature_costs explainer; the guide
  # deep-links to the matching #anchor. Kept beside the keys (not as an in-view
  # literal) so the list has one home; mirrors the <h2 id="..."> anchors in
  # app/views/learn/feature_costs.html.erb. A key without a section (agentic)
  # falls back to the explainer index.
  FEATURE_COSTS_SECTIONS = %w[rag chatbot classification summarization coding_agent].freeze

  def feature_costs_link(pattern)
    return learn_feature_costs_path unless FEATURE_COSTS_SECTIONS.include?(pattern.key)

    "#{learn_feature_costs_path}##{pattern.key}"
  end

  # Two short paragraphs per task — "what drives cost here" — with DISTINCT
  # openings (the deck forbids a repeated "is not one call" opener). Plain
  # declaratives, grounded in each pattern's real cost shape.
  LEDES = {
    "rag" => [
      "Retrieval does the hard part. The model reads a few fetched passages and answers without inventing, so most of the work is careful reading, not reasoning.",
      "That makes the shape input-heavy: thousands of context tokens go in to get a short paragraph back. The retrieved context is the meter, and it runs on every query."
    ],
    "coding_agent" => [
      "An agent reads a repo, plans a change, edits, runs tools, then re-checks. Each loop re-sends a growing context, so the same tokens get billed again and again.",
      "Three drivers stack at once: a long re-sent context, a tool loop that repeats, and reasoning that bills as output. The plan step is where capability earns its keep; the looping edit step is where the spend piles up."
    ],
    "chatbot" => [
      "A conversation accumulates. Every turn re-sends the transcript so the model keeps context, which means input grows with the dialogue and you pay to reprocess the history on each reply.",
      "The chain is intent, retrieve, generate. The cheap classify step runs every turn; the generate step does the answering and is the only place that needs a capable model."
    ],
    "classification" => [
      "A document goes in, a label or a small JSON object comes out. Moderation, routing, tagging, field extraction. The output is a rounding error.",
      "With output negligible, the input rate times volume is the whole bill, so tier choice is the only lever that moves it. Small models are purpose-built for this."
    ],
    "summarization" => [
      "The most input-heavy shape there is: a long document in, a short summary out. The input rate gets multiplied by every page you feed in.",
      "Output is modest and well-bounded, so the input meter scaled by length sets the cost. Cheap long-context models handle routine summaries; no step here reaches for a frontier model."
    ],
    "agentic" => [
      "An orchestrator delegates repeated search and tool work to cheap subagents, then synthesises what they find. The fan-out is where the calls multiply.",
      "The mismatch is the point: the money sits on the small looping subagent step, while the capability sits on the separate orchestrator. The cost-driver step and the capable-model step are different models."
    ]
  }.freeze

  # Three short cost drivers per task. Plain noun-led declaratives.
  DRIVERS = {
    "rag" => [
      "Retrieved context dominates the input, on every query.",
      "Output is short, so the input rate sets the bill.",
      "Retrieval precision moves cost more than any model swap."
    ],
    "coding_agent" => [
      "A long context, re-sent on every loop step.",
      "A tool loop that repeats many times per task.",
      "Reasoning tokens, billed as output, often longer than the visible action."
    ],
    "chatbot" => [
      "Re-sent transcript grows with every turn.",
      "The classify step runs once per turn, cheaply.",
      "The stable prefix is highly cacheable."
    ],
    "classification" => [
      "Input rate times volume is the entire bill.",
      "Output is a rounding error.",
      "Tier choice is the only lever that moves it."
    ],
    "summarization" => [
      "Document length scales the input meter directly.",
      "Output is modest and bounded.",
      "Over-sending boilerplate inflates every call."
    ],
    "agentic" => [
      "Subagent fan-out multiplies the cheap calls.",
      "The looping search step carries most of the spend.",
      "The orchestrator runs less often but needs capability."
    ]
  }.freeze

  def guide_lede(pattern)
    LEDES.fetch(pattern.key)
  end

  def guide_drivers(pattern)
    DRIVERS.fetch(pattern.key)
  end

  # The deepened "how to choose for {task}" block — unique editorial per task,
  # grounded in that task's real pipeline. Each is written to its own steps: the
  # cost-driver step, the capable-model step (when there is one), and the
  # specific lever that moves this shape. Distinct prose per task, not a
  # template; that is what the guide pages need to out-rank the explainer.
  # Voice: plain declaratives, "per call", "the guide" lowercase, locked terms
  # "cost-driver step" / "capable-model step", no drama em-dashes.
  CHOOSING = {
    "rag" => [
      "The chain is embed, retrieve, then generate answer. Almost the whole bill lands on the last step, where thousands of retrieved tokens go in for a short paragraph back, so generate answer is both the cost-driver step and the capable-model step.",
      "Pick the cheapest model that answers your retrieved context faithfully and start there. Spend on retrieval precision before you spend on a bigger model: three relevant passages instead of ten cuts the input meter on every call, and a model swap rarely beats that. Move up a tier only when the answers miss something a human reading the same passages would catch."
    ],
    "coding_agent" => [
      "Three steps, three jobs: plan decides what to change, edit / tool-call makes it across a looping context, and verify checks the result. The cost-driver step and the capable-model step are different here, and getting that split right is the whole game.",
      "Put the capable model on plan, the step that decides the change. The spend piles up on edit / tool-call, where a long context is re-sent on every loop, so the lever there is cached input, not a bigger model. Keep verify on a small model. A frontier model across the whole loop pays frontier rates for steps that never needed it."
    ],
    "chatbot" => [
      "Every turn runs intent / route, then retrieve, then generate reply, and the transcript grows each turn. The cost-driver step and the capable-model step are different: the cheap classify and retrieve steps run on every turn, while generate reply is the only one that needs a capable model.",
      "Start generate reply on a small or mid model and reserve a step up for genuinely hard threads. Keep intent / route and retrieve small; they run constantly and should cost almost nothing per call. The stable prefix of the transcript is highly cacheable, which is the single biggest lever on this shape."
    ],
    "classification" => [
      "One step, classify / extract, runs at volume: a document in, a label or small JSON object out. There is no capable-model step. Output is a rounding error, so the input rate times your volume is effectively the entire bill.",
      "Tier choice is the only lever that moves it, and small models are purpose-built for this, so start small and let an eval tell you whether you can keep it. Watch cost per accepted result, not cost per call: a cheap model that mislabels and forces a human review is not cheap. These jobs rarely care about latency, so batch pricing often stacks on top."
    ],
    "summarization" => [
      "One step, summarise: a long document in, a short summary out. No step here needs a frontier model. The input meter scaled by document length sets the cost, and the cost-driver step is summarise itself.",
      "Cheap long-context models have made routine summarisation a small-tier task, so start there. The lever after tier choice is not over-sending: strip boilerplate, headers, and repeated front-matter before the document goes in, because every token you send is priced on every call. Pay for a higher tier only when missing a clause buried mid-document actually carries a cost."
    ],
    "agentic" => [
      "An orchestrator delegates repeated work to cheap subagents, then a final step synthesises it. The cost-driver step and the capable-model step are different, and the mismatch is sharp: the money sits on the small, looping subagent search step, while the capability sits on the separate orchestrate / plan step.",
      "Put the capable model on orchestrate / plan and keep subagent search on a small model, because it loops many times and carries most of the spend. Cutting the number of fan-out calls moves the bill more than upgrading any single model. Reach for a bigger subagent only when cheap exploration keeps coming back wrong."
    ]
  }.freeze

  # The two short paragraphs of unique "how to choose for {task}" prose,
  # rendered paragraph-by-paragraph in the view.
  def guide_choosing_paras(pattern)
    CHOOSING.fetch(pattern.key)
  end

  # The takeaway, computed from the steps (AUDIT #4). Three branches:
  #
  #   * different steps    → name both; "they are different", spend on the
  #                          capable-model step, keep the rest small.
  #   * the same step      → name it once; spend there, keep the rest small.
  #   * no capability step → don't assert a contrast or an empty name; say a
  #                          small model handles the cost-driver step.
  #
  # The slots come from the data — a missing capability step takes the third
  # branch rather than rendering "the capable-model step () …".
  def guide_takeaway(pattern)
    driver_role = pattern.cost_driver_step&.role
    capable_role = pattern.capable_step&.role

    case pattern.driver_and_capable_relationship
    when :no_capability
      # No step needs a capable model (summarization, classification).
      if driver_role
        "No step here needs a frontier model. The bill concentrates on the cost-driver step (#{driver_role}); a small model handles it."
      else
        "No step here needs a frontier model, and none dominates the bill; a small model handles the whole chain."
      end
    when :same
      # Cost-driver and capable-model are the same step (rag, chatbot).
      "The cost-driver step and the capable-model step are the same one: #{capable_role}. Spend there; keep the rest small."
    else
      # They are different steps (coding_agent, agentic) — the payoff.
      "The cost-driver step is #{driver_role}. The capable-model step is #{capable_role}. They are different, so put the capable model on #{capable_role} and keep the rest small."
    end
  end
end
