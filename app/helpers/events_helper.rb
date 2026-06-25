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

    events.sort_by(&:date)
  end

  # Group a timeline into [year, events] pairs for the events page: newest year
  # first, and within each year newest event first.
  def events_by_year(events)
    events
      .group_by { |e| e.date.year }
      .sort_by { |year, _| -year }
      .map { |year, group| [ year, group.sort_by(&:date).reverse ] }
  end

  # Per-kind presentation for the timeline node + chip. The CSS hook is
  # `ev-#{kind}`, so only the human label and node icon live here.
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
