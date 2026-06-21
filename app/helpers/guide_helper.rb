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
    driver = pattern.steps.find(&:cost_driver?)
    capable = pattern.steps.find(&:capability?)

    driver_role = driver&.role
    capable_role = capable&.role

    if capable.nil?
      # No step needs a capable model (summarization, classification).
      if driver_role
        "No step here needs a frontier model. The bill concentrates on the cost-driver step (#{driver_role}); a small model handles it."
      else
        "No step here needs a frontier model, and none dominates the bill; a small model handles the whole chain."
      end
    elsif driver.nil? || driver_role == capable_role
      # Cost-driver and capable-model are the same step (rag, chatbot).
      role = capable_role
      "The cost-driver step and the capable-model step are the same one: #{role}. Spend there; keep the rest small."
    else
      # They are different steps (coding_agent, agentic) — the payoff.
      "The cost-driver step is #{driver_role}. The capable-model step is #{capable_role}. They are different, so put the capable model on #{capable_role} and keep the rest small."
    end
  end
end
