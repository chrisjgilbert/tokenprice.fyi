module EventsHelper
  Event = Data.define(:date, :title, :kind, :note, :model, :provider, :source_url, :so_what, :citations)

  # The launch-timeline blurb for a model: "ships X at $Y in / $Z out per 1M".
  # Every listed model is priced, so the else is a defensive fallback only.
  def launch_note(model)
    base = "#{model.provider.name} ships #{model.name}"
    if model.current_price
      "#{base} at #{usd_plain(model.current_input)} in / #{usd_plain(model.current_output)} out per 1M."
    else
      "#{base}. Price not yet tracked."
    end
  end

  def build_all_events(models: AiModel.listed.includes(:provider, :price_points), market_events: MarketEvent.listed)
    events = []

    market_events.each do |me|
      events << Event.new(
        date: me.event_date,
        title: me.title,
        kind: "market",
        note: me.note,
        model: nil,
        provider: nil,
        source_url: me.source_url,
        so_what: me.so_what,
        citations: me.citations
      )
    end

    # Each listed model contributes a launch entry. Price changes are not
    # surfaced here — they're noisy and mostly inconsequential; significant
    # ones are curated as MarketEvents instead. Full per-model price history
    # still lives on the model page.
    models.each do |m|
      next unless m.released_on

      events << Event.new(
        date: m.released_on,
        title: "#{m.name} released",
        kind: "launch",
        note: launch_note(m),
        model: m,
        provider: m.provider,
        source_url: nil,
        so_what: nil,
        citations: []
      )
    end

    # Deterministic ascending order: date, then kind, then title. The tertiary
    # keys give same-date events a stable order (Ruby's sort_by is not stable),
    # so both the homepage hero's `.last` pick and events_by_year's reverse are
    # reproducible rather than dependent on undefined tie ordering.
    events.sort_by { |e| [ e.date, e.kind, e.title ] }
  end

  # The hero's "Latest events" slice: one per kind, then fill remaining slots
  # with the most-recent of any kind.
  def hero_events(events, count: 2)
    newest_first = events.sort_by { |e| [ e.date, e.kind, e.title ] }.reverse
    picked = []
    newest_first.each do |e|
      next if picked.any? { |p| p.kind == e.kind }
      picked << e
      break if picked.size == count
    end
    newest_first.each do |e|
      break if picked.size == count
      picked << e unless picked.include?(e)
    end
    picked
  end

  # Group a timeline into [year, events] pairs for the events page: newest year
  # first, and within each year newest event first. Order-independent of the
  # input — it sorts both the years and each group itself — so it produces the
  # same display whether handed the full ascending list or a pre-reversed page
  # slice (the events controller paginates on the reversed list).
  def events_by_year(events)
    events
      .group_by { |e| e.date.year }
      .sort_by { |year, _| -year }
      .map { |year, group| [ year, group.sort_by { |e| [ e.date, e.kind, e.title ] }.reverse ] }
  end

  # Freshness timestamp for everything build_all_events renders — used as the
  # Last-Modified for conditional GET on both the events timeline and the
  # homepage hero, the two pages built from it. It spans every source the
  # timeline reads: price points and curated market events, plus the model and
  # provider rows whose names, dates, and tiers appear in the launch entries —
  # so an admin edit to any of them revalidates instead of serving a stale 304.
  # A few indexed MAX() aggregates over small tables; no rows are loaded.
  def timeline_last_modified
    [
      PriceCatalog.last_modified,
      MarketEvent.maximum(:updated_at),
      AiModel.maximum(:updated_at),
      Provider.maximum(:updated_at)
    ].compact.max
  end

  # Per-kind presentation, the single source for how each event kind reads.
  # Colours live in CSS (`ev-#{kind}` for the timeline node, `tp-kind-#{kind}`
  # and `hero-card-kind-chip.#{kind}` for the chips), so only the words and the
  # node icon live here. `hero` is the homepage's product-facing wording ("New
  # model") next to the timeline's terser `label` ("Launch"); `noun` is the
  # plural used in the empty state.
  EVENT_KINDS = {
    "market" => { label: "Market", hero: "Market event", noun: "market events", icon: :bolt },
    "launch" => { label: "Launch", hero: "New model",    noun: "launches",      icon: :spark }
  }.freeze

  def event_kind_label(kind)
    EVENT_KINDS.dig(kind, :label) || kind.to_s.titleize
  end

  def hero_kind_chip_label(kind)
    EVENT_KINDS.dig(kind, :hero) || kind.to_s.titleize
  end

  def event_kind_noun(kind)
    EVENT_KINDS.dig(kind, :noun) || kind.to_s.titleize
  end

  def event_kind_icon(kind)
    EVENT_KINDS.dig(kind, :icon) || :calendar
  end

  # The bare host for a citation chip — "techcrunch.com" reads better than a long
  # title or full URL. The full title rides along as the link's tooltip.
  def citation_host(url)
    URI.parse(url).host&.delete_prefix("www.") || url
  rescue URI::InvalidURIError
    url
  end
end
