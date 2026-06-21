# FeaturePattern — the single source of truth for the model Guide and the
# anatomy explainer. A feature is a chain of calls, each with a different job;
# we model that ONCE, as data, so the Guide (per-step interactive view) and the
# education explainer (worked call-chain) render from the same step objects and
# can never drift apart (see docs/MODEL_GUIDE_SPEC.md §2, AUDIT #2).
#
# This is a plain Ruby value object with a frozen in-code registry — NOT
# ActiveRecord. It matches the CostEstimate idiom: Data.define + a frozen
# REGISTRY. It does not touch the database: the per-step `options` are model
# slugs (derived from a model's name.parameterize, e.g. "Claude Opus 4.8" =>
# "claude-opus-4-8"). Resolving those slugs against the live PriceCatalog — with
# graceful fallback for an unknown slug — is the next task's job; this layer
# stays DB-free and just carries the editorial curation.
#
# The two payoff fields are `cost_driver` and `capability`: they are often
# DIFFERENT steps, and that mismatch is the thing developers get wrong (one
# frontier model for the whole chain when only the generate/plan step needed
# it). Honouring that mismatch in the data is the whole point.
class FeaturePattern
  TIERS = %w[small mid frontier].freeze

  # A representative per-call token shape for a step. Counts reflect the step's
  # real cost shape (RAG generate: large `in` from retrieved context, short
  # `out`; summarization: large `in`, short `out`; coding agent: big `out`).
  Shape = Data.define(:sys, :in, :out) do
    def to_h = { sys:, in:, out: }
    def [](key) = to_h[key]
  end

  # 2–3 curated starting-option model slugs for a step: a cheap default (small
  # tier), a quality step-up (mid/frontier), and an open-weight option. Any may
  # be nil, but a step always has at least one. These are slugs, not records.
  #
  # Convention: `cheap` is the cheapest VIABLE option and may sit one tier below
  # the step's stated `tier`; `quality` is the option that meets the stated
  # tier; `open_weight` is orthogonal to the tier ladder. The step's `tier` badge
  # and the "see all {tier}-tier models" link both refer to the stated tier.
  Options = Data.define(:cheap, :quality, :open_weight) do
    def to_h = { cheap:, quality:, open_weight: }
    def values = to_h.values
    def each_value(&) = to_h.each_value(&)
  end

  # One call in the chain. `tier` is the *starting* tier for the step.
  # `cost_driver`/`capability` are the payoff predicates. `loops` flags a step
  # that repeats (agents). `priced` is false for plumbing that isn't a chat
  # completion — e.g. the RAG embed step, whose embeddings live on a separate
  # endpoint the catalog doesn't carry (AUDIT #5); never fabricate a price.
  Step = Data.define(
    :role, :purpose, :tier, :shape,
    :cost_driver, :capability, :loops, :options, :priced
  ) do
    def cost_driver? = !!cost_driver
    def capability?  = !!capability
    def loops?       = !!loops
    def priced?      = priced != false
  end

  attr_reader :key, :label, :blurb, :steps

  def initialize(key:, label:, blurb:, steps:)
    @key = key
    @label = label
    @blurb = blurb
    @steps = steps
    freeze
  end

  # --- the driver/capable relationship, derived once from the steps ---
  #
  # A feature's cost-driver step and capable-model step are often DIFFERENT
  # steps, sometimes the SAME step, and sometimes there is NO capable-model step
  # at all (summarization, classification). The guide takeaway and the anatomy
  # reading both branch on this relationship; computing it here keeps that
  # branching single-sourced (AUDIT #2) so the two views can never drift.

  # The first step that drives the bill, or nil if none is flagged.
  def cost_driver_step = steps.find(&:cost_driver?)

  # The first step that needs a capable model, or nil if none is flagged.
  def capable_step = steps.find(&:capability?)

  # How the cost-driver step and the capable-model step relate:
  #   :no_capability — no step needs a capable model (the bill, if it
  #                    concentrates anywhere, sits on a small model).
  #   :same          — one step is both the cost driver and the capable step.
  #   :different     — the cost driver and the capable step are distinct steps.
  # A missing cost driver alongside a present capable step reads as :same
  # (there is no contrast to draw), matching the takeaway/anatomy branching.
  def driver_and_capable_relationship
    capable = capable_step
    return :no_capability if capable.nil?

    driver = cost_driver_step
    return :same if driver.nil? || driver.equal?(capable)

    :different
  end

  # --- construction helpers (keep the registry below readable) ---

  def self.step(role:, purpose:, tier:, shape:, options:,
                cost_driver: false, capability: false, loops: false, priced: true)
    Step.new(
      role:, purpose:, tier:,
      shape: Shape.new(**shape),
      cost_driver:, capability:, loops:,
      options: Options.new(cheap: options[:cheap], quality: options[:quality], open_weight: options[:open_weight]),
      priced:
    )
  end

  # ---------------------------------------------------------------------------
  # The registry — the six launch tasks, ordered. Token shapes and tier/role
  # assignments are mined from the retired /which-model task→tier verdicts (now
  # 301'd to the guide) and app/views/learn/feature_costs.html.erb, restructured
  # into data.
  # ---------------------------------------------------------------------------
  REGISTRY = [
    # RAG support bot. Input-heavy: thousands of context tokens in, a paragraph
    # out. The embed step is plumbing on a separate embeddings endpoint — kept
    # in the chain but unpriced (AUDIT #5). Generate is both the cost driver
    # (the big retrieved context) and the step that needs the capable model;
    # the cheap-vs-smart mismatch shows up more sharply in the agent patterns.
    new(
      key: "rag",
      label: "RAG support bot",
      blurb: "Answer questions over retrieved documents, grounded and citable.",
      steps: [
        step(
          role: "embed query",
          purpose: "turn the question into a vector to search the index",
          tier: "small",
          shape: { sys: 1, in: 50, out: 1 },
          cost_driver: false, capability: false, priced: false,
          options: { cheap: "gpt-4-1-nano", quality: nil, open_weight: "mistral-small-4" }
        ),
        step(
          role: "retrieve / rerank",
          purpose: "score and order candidate passages so only the best go in",
          tier: "small",
          shape: { sys: 200, in: 2_000, out: 30 },
          cost_driver: false, capability: false,
          options: { cheap: "claude-haiku-4-5", quality: "gemini-3-5-flash", open_weight: "mistral-small-4" }
        ),
        step(
          role: "generate answer",
          purpose: "read the retrieved context and answer without inventing",
          tier: "mid",
          shape: { sys: 500, in: 4_550, out: 250 },
          cost_driver: true, capability: true,
          options: { cheap: "claude-haiku-4-5", quality: "claude-sonnet-4-6", open_weight: "llama-4-maverick" }
        )
      ]
    ),

    # Coding agent. Big outputs (diffs, reasoning), a long re-sent context.
    # The plan step needs the capable model; the looping edit/tool step is where
    # the spend stacks up via re-sent cached context. Distinct steps.
    new(
      key: "coding_agent",
      label: "Coding agent",
      blurb: "Read a repo, plan, edit, run tools, re-check — across many steps.",
      steps: [
        step(
          role: "plan",
          purpose: "decompose the task and decide what to change",
          tier: "frontier",
          shape: { sys: 2_500, in: 8_000, out: 1_200 },
          cost_driver: false, capability: true,
          options: { cheap: "claude-sonnet-4-6", quality: "claude-opus-4-8", open_weight: "deepseek-v4-pro" }
        ),
        step(
          role: "edit / tool-call",
          purpose: "make changes and run tools, re-sending the growing context each step",
          tier: "frontier",
          shape: { sys: 2_500, in: 24_000, out: 2_000 },
          cost_driver: true, capability: false, loops: true,
          options: { cheap: "claude-sonnet-4-6", quality: "claude-opus-4-8", open_weight: "deepseek-v4-pro" }
        ),
        step(
          role: "verify",
          purpose: "read tool output and decide whether the change is correct",
          tier: "small",
          shape: { sys: 1_000, in: 6_000, out: 200 },
          cost_driver: false, capability: false,
          options: { cheap: "claude-haiku-4-5", quality: "gemini-3-5-flash", open_weight: "mistral-small-4" }
        )
      ]
    ),

    # Support chatbot. intent → route → retrieve → generate. The cheap classify
    # step runs every turn; the generate step does the actual answering and is
    # where capability is needed. Distinct cost-driver / capability steps.
    new(
      key: "chatbot",
      label: "Support chatbot",
      blurb: "A multi-turn conversation that routes, retrieves, and replies.",
      steps: [
        step(
          role: "intent / route",
          purpose: "classify the message and pick a path (FAQ, handoff, tool)",
          tier: "small",
          shape: { sys: 400, in: 300, out: 5 },
          cost_driver: false, capability: false,
          options: { cheap: "gpt-4-1-nano", quality: "claude-haiku-4-5", open_weight: "mistral-small-4" }
        ),
        step(
          role: "retrieve",
          purpose: "pull relevant help-centre passages for grounding",
          tier: "small",
          shape: { sys: 200, in: 1_500, out: 30 },
          cost_driver: false, capability: false,
          options: { cheap: "claude-haiku-4-5", quality: "gemini-3-5-flash", open_weight: "llama-4-scout" }
        ),
        step(
          role: "generate reply",
          purpose: "answer in context, re-sending the accumulating transcript each turn",
          tier: "mid",
          shape: { sys: 400, in: 3_100, out: 250 },
          cost_driver: true, capability: true,
          options: { cheap: "claude-haiku-4-5", quality: "claude-sonnet-4-6", open_weight: "llama-4-maverick" }
        )
      ]
    ),

    # Classification / extraction. A document in, a label or small JSON out.
    # Output is a rounding error; the single call is both the whole bill and the
    # only place capability could matter — small tier purpose-built for it.
    new(
      key: "classification",
      label: "Classification / extraction",
      blurb: "A document in, a label or small JSON object out. Output is tiny.",
      steps: [
        step(
          role: "classify / extract",
          purpose: "label the document or pull structured fields to JSON",
          tier: "small",
          shape: { sys: 300, in: 800, out: 5 },
          cost_driver: true, capability: false,
          options: { cheap: "gpt-4-1-nano", quality: "claude-haiku-4-5", open_weight: "mistral-small-4" }
        )
      ]
    ),

    # Summarization (AUDIT #4). Long document in, short summary out — the most
    # input-heavy shape. It has a cost-driver step but NO step needs the capable
    # model: cheap long-context models do routine summarisation. The
    # no-capability case must be representable AND present — so it is here.
    new(
      key: "summarization",
      label: "Summarisation",
      blurb: "A long document in, a short summary out. The most input-heavy shape.",
      steps: [
        step(
          role: "summarise",
          purpose: "compress a long document into a short, faithful summary",
          tier: "small",
          shape: { sys: 300, in: 22_000, out: 600 },
          cost_driver: true, capability: false,
          options: { cheap: "gpt-4-1-mini", quality: "claude-haiku-4-5", open_weight: "llama-4-scout" }
        )
      ]
    ),

    # Agentic workflow (AUDIT intro). The cost driver sits on a SMALL-tier
    # looping step (cheap subagents doing repeated search/exploration), while
    # the capability step is the separate, more-capable orchestrator/plan. The
    # mismatch is real, not a contrivance: the money is on the small loop, the
    # smarts are elsewhere.
    new(
      key: "agentic",
      label: "Agentic workflow",
      blurb: "An orchestrator delegating repeated search and tool work to cheap subagents.",
      steps: [
        step(
          role: "orchestrate / plan",
          purpose: "decide the next move and synthesise subagent results",
          tier: "frontier",
          shape: { sys: 3_000, in: 9_000, out: 1_500 },
          cost_driver: false, capability: true,
          options: { cheap: "claude-sonnet-4-6", quality: "claude-opus-4-8", open_weight: "qwen-3-7-max" }
        ),
        step(
          role: "subagent search",
          purpose: "fan out cheap exploration/tool calls, repeated many times",
          tier: "small",
          shape: { sys: 800, in: 4_000, out: 400 },
          cost_driver: true, capability: false, loops: true,
          options: { cheap: "claude-haiku-4-5", quality: "gemini-3-5-flash", open_weight: "mistral-small-4" }
        ),
        step(
          role: "final answer",
          purpose: "produce the user-facing result from gathered evidence",
          tier: "mid",
          shape: { sys: 1_000, in: 6_000, out: 700 },
          cost_driver: false, capability: false,
          options: { cheap: "claude-haiku-4-5", quality: "claude-sonnet-4-6", open_weight: "llama-4-maverick" }
        )
      ]
    )
  ].freeze

  BY_KEY = REGISTRY.index_by(&:key).freeze

  # All patterns, in launch order.
  def self.all = REGISTRY

  # The pattern for `key`, or nil for an unknown key.
  def self.find(key)
    return nil if key.nil?

    BY_KEY[key.to_s]
  end
end
