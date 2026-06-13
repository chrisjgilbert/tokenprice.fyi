module EventsHelper
  Event = Data.define(:date, :title, :kind, :note, :model, :provider)

  def build_all_events(models: AiModel.listed.includes(:provider, :price_points), market_events: MarketEvent.listed)
    events = []

    market_events.each do |me|
      events << Event.new(
        date: me.event_date,
        title: me.title,
        kind: "market",
        note: me.note,
        model: nil,
        provider: nil
      )
    end

    models.each do |m|
      next if m.released_on.nil?

      events << Event.new(
        date: m.released_on,
        title: "#{m.name} released",
        kind: "launch",
        note: "#{m.provider.name} ships #{m.name} at #{usd_plain(m.blended_per_mtok)} I/O avg /1M.",
        model: m,
        provider: m.provider
      )
    end

    events.sort_by(&:date)
  end
end
