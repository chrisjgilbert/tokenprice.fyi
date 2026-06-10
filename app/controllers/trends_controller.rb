class TrendsController < ApplicationController
  def index
    models = AiModel.listed.includes(:provider, :price_points).to_a

    @models_json = models.map do |m|
      {
        slug:     m.slug,
        name:     m.name,
        provider: m.provider.slug,
        provider_name: m.provider.name,
        provider_accent: m.provider.accent,
        tier:     m.tier,
        history:  m.price_points.sort_by(&:effective_on).map do |pp|
          {
            date:   pp.effective_on.iso8601,
            input:  pp.input_per_mtok.to_f,
            output: pp.output_per_mtok.to_f
          }
        end
      }
    end.to_json

    @events_json = MarketEvent.chronological.map do |me|
      {
        date:  me.event_date.iso8601,
        title: me.title,
        kind:  me.kind,
        note:  me.note
      }
    end.to_json

    # Also build launch events from models
    launch_events = models.select { |m| m.released_on }.map do |m|
      {
        date:  m.released_on.iso8601,
        title: "#{m.name} released",
        kind:  "launch",
        note:  "#{m.provider.name} ships #{m.name}.",
        model: m.slug
      }
    end

    market_events = MarketEvent.chronological.map do |me|
      {
        date:  me.event_date.iso8601,
        title: me.title,
        kind:  me.kind,
        note:  me.note,
        model: nil
      }
    end

    @all_events_json = (market_events + launch_events).sort_by { |e| e[:date] }.to_json
  end
end
