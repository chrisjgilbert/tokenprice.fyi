module LearnHelper
  # The explainer series — the index cards, page headers, and estimator
  # pre-fills all read from here (ported from LEARN.CONCEPTS). `live` concepts
  # have a built page; the rest render as "Next up" cards. `w` is the workload
  # the concept's estimator CTA is pre-filled with.
  def learn_concepts
    [
      { num: "01", slug: "pricing", title: "How LLM API pricing works", icon: :coin, tint: "#6366f1", read: "6 min",
        dek: "Tokens, the input/output split, cached reads, and why the same answer costs several times more to write than to read.",
        path: how_pricing_works_path, live: true,
        w: { sys: 1200, fresh: 300, out: 600, req: 200_000, cache: 0, tier: "mid", summary: "Typical chat request" } },
      { num: "02", slug: "caching", title: "Prompt caching", icon: :cache, tint: "#0ea5e9", read: "5 min",
        dek: "Reuse a big system prompt or document across calls and pay up to 90% less for the repeated part.",
        path: nil, live: false,
        w: { sys: 8000, fresh: 300, out: 500, req: 150_000, cache: 80, tier: "mid", summary: "RAG over fixed docs" } },
      { num: "03", slug: "batch", title: "Batch processing", icon: :batch, tint: "#10b981", read: "4 min",
        dek: "Trade latency for ~50% off. When a job can wait minutes, the async batch endpoint halves the bill.",
        path: nil, live: false,
        w: { sys: 600, fresh: 1200, out: 300, req: 1_000_000, cache: 0, tier: "small", summary: "Bulk summarization" } },
      { num: "04", slug: "reasoning", title: "Reasoning & “thinking” tokens", icon: :brain, tint: "#7c3aed", read: "6 min",
        dek: "Reasoning models bill the hidden thinking they do before answering — often the biggest line on the invoice.",
        path: nil, live: false,
        w: { sys: 800, fresh: 1000, out: 2500, req: 40_000, cache: 0, tier: "frontier", summary: "Hard reasoning task" } },
      { num: "05", slug: "agent", title: "What an AI agent actually costs", icon: :agent, tint: "#f59e0b", read: "7 min",
        dek: "An agent makes many model calls per task, each carrying a growing transcript. The cost compounds fast.",
        path: nil, live: false,
        w: { sys: 3000, fresh: 1500, out: 900, req: 40_000, cache: 60, tier: "frontier", summary: "Coding agent run" } },
      { num: "06", slug: "features", title: "What drives the cost of common features", icon: :blocks, tint: "#e11d48", read: "8 min",
        dek: "RAG, chat, classification, summarization, a coding agent — each has a different cost shape. Here's why.",
        path: learn_feature_costs_path, live: true,
        w: { sys: 2000, fresh: 600, out: 400, req: 200_000, cache: 50, tier: "mid", summary: "Feature cost shapes" } },
      { num: "07", slug: "cutting", title: "Cost-cutting strategies & savings", icon: :scissors, tint: "#0d9488", read: "6 min",
        dek: "Tiering, routing, caching, shorter outputs, batch. The levers that move a bill the most — and by how much.",
        path: learn_cost_cutting_path, live: true,
        w: { sys: 1800, fresh: 240, out: 380, req: 450_000, cache: 70, tier: "frontier", summary: "Optimization sandbox" } }
    ]
  end

  def learn_concept(slug)
    learn_concepts.find { |c| c[:slug] == slug }
  end

  # The estimator CTA URL, pre-filled for a concept.
  def concept_cta_path(concept)
    cost_cta_path(concept[:w])
  end

  # A single decorative stat for the /learn index featured panel — the median
  # output:input multiple across the catalog. (The index carries only this one
  # stat line, never a live-data widget; those live inside the explainers.)
  def live_output_input_multiple
    priced = PriceCatalog.models.select { |m| m.input.to_f.positive? && m.output }
    return nil if priced.empty?

    ratios = priced.map { |m| m.output / m.input }.sort
    ratios[ratios.size / 2].round(1)
  end

  LEARN_ICONS = {
    coin:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M14.8 9a2.5 2.5 0 0 0-2.3-1.4c-1.4 0-2.5.9-2.5 2s1 1.7 2.5 2 2.5.9 2.5 2-1.1 2-2.5 2A2.5 2.5 0 0 1 9.2 15"/><path d="M12 6v1.6M12 16.4V18"/></svg>',
    cache: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-9-9c2.5 0 4.7 1 6.3 2.7L21 8"/><path d="M21 3v5h-5"/></svg>',
    batch: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>',
    brain: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5a3 3 0 1 0-5.9.8A3 3 0 0 0 4 9a3 3 0 0 0 1.5 2.6A3 3 0 0 0 7 17a3 3 0 0 0 5 1 3 3 0 0 0 5-1 3 3 0 0 0 1.5-5.4A3 3 0 0 0 20 9a3 3 0 0 0-2.1-3.2A3 3 0 0 0 12 5Z"/><path d="M12 5v13"/></svg>',
    agent: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="8" width="16" height="12" rx="2"/><path d="M12 8V4M9 2h6"/><circle cx="9" cy="14" r="1"/><circle cx="15" cy="14" r="1"/></svg>',
    blocks: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 2 9 5-9 5-9-5 9-5Z"/><path d="m3 12 9 5 9-5"/><path d="m3 17 9 5 9-5"/></svg>',
    scissors: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M20 4 8.12 15.88M14.47 14.48 20 20M8.12 8.12 12 12"/></svg>'
  }.freeze

  def learn_icon(name, size: 21)
    raw %(<span style="display:inline-flex;width:#{size}px;height:#{size}px">#{LEARN_ICONS[name.to_sym]}</span>)
  end

  # A concept card for the index series grid / next-in-series footer.
  def learn_concept_card(concept, delay: nil)
    tint = concept[:tint]
    style = delay ? "animation-delay:#{delay}s" : nil
    inner = capture do
      concat content_tag(:div, class: "led-card-top") {
        content_tag(:span, learn_icon(concept[:icon]), class: "led-ico", style: "background:#{tint}1a;color:#{tint}") +
          (concept[:live] ? content_tag(:span, concept[:num], class: "led-num") : content_tag(:span, "Next up", class: "led-soon"))
      }
      concat content_tag(:h4, concept[:title])
      concat content_tag(:p, concept[:dek])
      concat content_tag(:div, class: "led-card-foot") {
        content_tag(:span, "#{concept[:num]} · #{concept[:read]}") +
          (concept[:live] ? content_tag(:span, class: "go") { safe_join([ "Read", co_icon(:arrow_right, size: 14) ]) } : "".html_safe)
      }
    end
    if concept[:live]
      link_to inner, concept[:path], class: "card led-card reveal", style: style
    else
      content_tag(:div, inner, class: "card led-card is-soon reveal", style: style)
    end
  end
end
