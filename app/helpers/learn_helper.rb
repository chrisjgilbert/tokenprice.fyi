module LearnHelper
  # The three built explainers. Each entry drives an index card and its own
  # page header. All three have a live page; the index links straight to them.
  def learn_concepts
    [
      { title: "How LLM API pricing works", icon: :coin, tint: "#6366f1", read: "6 min",
        dek: "Tokens, the input/output split, cached reads, and why the same answer costs several times more to write than to read.",
        path: how_pricing_works_path },
      { title: "What drives the cost of common features", icon: :blocks, tint: "#e11d48", read: "8 min",
        dek: "RAG, chat, classification, summarization, a coding agent — each has a different cost shape. Here's why.",
        path: learn_feature_costs_path },
      { title: "Cost-cutting strategies & savings", icon: :scissors, tint: "#0d9488", read: "6 min",
        dek: "Tiering, routing, caching, shorter outputs, batch. The levers that move a bill the most, and by how much.",
        path: learn_cost_cutting_path }
    ]
  end

  LEARN_ICONS = {
    coin:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M14.8 9a2.5 2.5 0 0 0-2.3-1.4c-1.4 0-2.5.9-2.5 2s1 1.7 2.5 2 2.5.9 2.5 2-1.1 2-2.5 2A2.5 2.5 0 0 1 9.2 15"/><path d="M12 6v1.6M12 16.4V18"/></svg>',
    blocks: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 2 9 5-9 5-9-5 9-5Z"/><path d="m3 12 9 5 9-5"/><path d="m3 17 9 5 9-5"/></svg>',
    scissors: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M20 4 8.12 15.88M14.47 14.48 20 20M8.12 8.12 12 12"/></svg>'
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
end
