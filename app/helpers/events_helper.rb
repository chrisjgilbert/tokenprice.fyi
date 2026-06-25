module EventsHelper
  Event = Data.define(:date, :title, :kind, :note, :model, :provider, :source_url)

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
        source_url: me.source_url
      )
    end

    models.each do |m|
      next if m.released_on.nil?

      events << Event.new(
        date: m.released_on,
        title: "#{m.name} released",
        kind: "launch",
        note: "#{m.provider.name} ships #{m.name} at #{usd_plain(m.current_input)} in / #{usd_plain(m.current_output)} out per 1M.",
        model: m,
        provider: m.provider,
        source_url: nil
      )
    end

    # Deterministic ascending order: date, then kind, then title. The tertiary
    # keys give same-date events a stable order (Ruby's sort_by is not stable),
    # so both the homepage hero's `.last` pick and events_by_year's reverse are
    # reproducible rather than dependent on undefined tie ordering.
    events.sort_by { |e| [ e.date, e.kind, e.title ] }
  end

  # Group a timeline into [year, events] pairs for the events page: newest year
  # first, and within each year newest event first. Relies on build_all_events
  # returning a deterministic ascending order — group_by preserves it within
  # each year, so a plain reverse yields newest-first without re-sorting.
  def events_by_year(events)
    events
      .group_by { |e| e.date.year }
      .sort_by { |year, _| -year }
      .map { |year, group| [ year, group.reverse ] }
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

  # Per-kind presentation for the timeline node + chip. Colours live in CSS
  # (`ev-#{kind}` for the node, `tp-kind-#{kind}` for the chip), so only the
  # human label and node icon live here.
  EVENT_KINDS = {
    "market" => { label: "Market", icon: :bolt },
    "launch" => { label: "Launch", icon: :spark }
  }.freeze

  def event_kind_label(kind)
    EVENT_KINDS.dig(kind, :label) || kind.to_s.titleize
  end

  def event_kind_icon(kind)
    EVENT_KINDS.dig(kind, :icon) || :calendar
  end
end
