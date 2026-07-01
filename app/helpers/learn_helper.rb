module LearnHelper
  # The five built explainers. Each entry drives an index card and its own page
  # header. Each has a live page; the index links straight to them. Order: the
  # two meter-mechanics pages (how pricing works, modality) first, then feature
  # cost and the levers, reasoning last (most advanced topic).
  def learn_concepts
    [
      { title: "How LLM API pricing works", icon: :coin, tint: "#6366f1", read: "6 min",
        dek: "Tokens, the input/output split, cached reads, and why the same answer costs several times more to write than to read.",
        path: how_pricing_works_path },
      { title: "Modality: images and audio on the meter", icon: :shapes, tint: "#0891b2", read: "6 min",
        dek: "An image or a clip of audio still bills in tokens, but the count comes from resolution or length, not meaning — and often at its own rate.",
        path: learn_modality_path },
      { title: "What drives the cost of common features", icon: :layers, tint: "#e11d48", read: "8 min",
        dek: "RAG, chat, classification, summarisation, a coding agent — each has a different cost shape. Here's why.",
        path: learn_feature_costs_path },
      { title: "Cost-cutting strategies & savings", icon: :scissors, tint: "#0d9488", read: "6 min",
        dek: "Tiering, routing, caching, shorter outputs, batch. The levers that move a bill the most, and by how much.",
        path: learn_cost_cutting_path },
      { title: "Reasoning & \"thinking\" tokens", icon: :brain, tint: "#7c3aed", read: "6 min",
        dek: "Reasoning models bill the hidden thinking they do before answering, at the output rate, and it is often the biggest line on the invoice. Effort dials the volume of that thinking, not the price per token.",
        path: learn_reasoning_path }
    ]
  end

  # Roadmap explainers, not written yet. They render as muted, non-link "Next up"
  # cards so the series shows where it's heading; the content lands later.
  def learn_upcoming
    [
      { title: "Prompt caching", icon: :refresh, tint: "#0ea5e9",
        dek: "Reuse a big system prompt or document across calls and pay up to 90% less for the repeated part." },
      { title: "Batch processing", icon: :grid, tint: "#10b981",
        dek: "Trade latency for around half off. When a job can wait minutes, the async batch endpoint cuts the bill." },
      { title: "What an AI agent actually costs", icon: :bot, tint: "#d97706",
        dek: "An agent makes many model calls per task, each carrying a growing transcript. The cost compounds fast." }
    ]
  end

  LEARN_ICONS = {
    coin:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M14.8 9a2.5 2.5 0 0 0-2.3-1.4c-1.4 0-2.5.9-2.5 2s1 1.7 2.5 2 2.5.9 2.5 2-1.1 2-2.5 2A2.5 2.5 0 0 1 9.2 15"/><path d="M12 6v1.6M12 16.4V18"/></svg>',
    scissors: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M20 4 8.12 15.88M14.47 14.48 20 20M8.12 8.12 12 12"/></svg>',
    layers: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7.5 12 3l9 4.5-9 4.5-9-4.5Z"/><path d="m3 12 9 4.5 9-4.5"/><path d="m3 16.5 9 4.5 9-4.5"/></svg>',
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-2.64-6.36"/><path d="M21 3v6h-6"/></svg>',
    grid: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>',
    brain: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 4a2.5 2.5 0 0 0-2.5 2.5A2.5 2.5 0 0 0 5 9a2.5 2.5 0 0 0 .5 4.5A2.5 2.5 0 0 0 8 18a2 2 0 0 0 2-2V4Z"/><path d="M14 4a2.5 2.5 0 0 1 2.5 2.5A2.5 2.5 0 0 1 19 9a2.5 2.5 0 0 1-.5 4.5A2.5 2.5 0 0 1 16 18a2 2 0 0 1-2-2V4Z"/></svg>',
    bot: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="8" width="16" height="11" rx="3"/><path d="M12 8V5"/><circle cx="12" cy="3.5" r="1.3"/><path d="M9 13h.01M15 13h.01"/></svg>',
    shapes: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="6.5" cy="6.5" r="3.5"/><rect x="13" y="13" width="8" height="8" rx="1.5"/><path d="M6.5 13.5 10 20.5H3l3.5-7Z"/></svg>'
  }.freeze

  def learn_icon(name, size: 21)
    raw %(<span style="display:inline-flex;width:#{size}px;height:#{size}px">#{LEARN_ICONS[name.to_sym]}</span>)
  end

  # An explainer card for the /learn directory grid.
  def learn_concept_card(concept, delay: nil)
    tint = concept[:tint]
    style = delay ? "animation-delay:#{delay}s" : nil
    inner = capture do
      concat content_tag(:div, class: "led-card-top") {
        content_tag(:span, learn_icon(concept[:icon]), class: "led-ico", style: "background:#{tint}1a;color:#{tint}")
      }
      concat content_tag(:h4, concept[:title])
      concat content_tag(:p, concept[:dek])
      concat content_tag(:div, class: "led-card-foot") {
        content_tag(:span, "#{concept[:read]} read") +
          content_tag(:span, class: "go") { safe_join([ "Read", co_icon(:arrow_right, size: 14) ]) }
      }
    end
    link_to inner, concept[:path], class: "card led-card reveal", style: style
  end

  # A muted, non-interactive "Next up" card for a roadmap explainer (no page yet).
  def learn_upcoming_card(concept, delay: nil)
    tint = concept[:tint]
    style = delay ? "animation-delay:#{delay}s" : nil
    content_tag(:div, class: "card led-card led-soon reveal", style: style) do
      concat content_tag(:div, class: "led-card-top") {
        content_tag(:span, learn_icon(concept[:icon]), class: "led-ico", style: "background:#{tint}1a;color:#{tint}") +
          content_tag(:span, "Next up", class: "led-soon-tag")
      }
      concat content_tag(:h4, concept[:title])
      concat content_tag(:p, concept[:dek])
    end
  end
end
