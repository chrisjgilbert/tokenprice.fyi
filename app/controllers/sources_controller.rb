class SourcesController < ApplicationController
  # Every PricePoint stores a bare source string ("anthropic.com/pricing",
  # "openrouter.ai", "scmp.com"). The attribution table buckets them by the
  # leading domain: anything not recognised below is treated as first-party —
  # a provider's own pricing page or announcement — which is the common case.
  THIRD_PARTY_DOMAINS = %w[
    openrouter.ai
    pricepertoken.com
    scmp.com
    engadget.com
    codersera.com
  ].freeze

  COMMUNITY_DOMAINS = %w[
    github.com
    raw.githubusercontent.com
  ].freeze

  GROUPS = [
    {
      key:   :first_party,
      title: "Provider pricing pages",
      blurb: "First-party — read straight off the provider's own pricing page or launch announcement. These are the preferred source for every price point."
    },
    {
      key:   :third_party,
      title: "Aggregators & press",
      blurb: "Third-party — marketplaces, price trackers, and reporting, used where a first-party capture wasn't available or to confirm a change the provider announced quietly."
    },
    {
      key:   :community,
      title: "Community datasets",
      blurb: "Open, community-maintained datasets used to discover when a price changed — every figure they surface is still verified against a first-party or archived page before it lands here."
    }
  ].freeze

  def index
    rows = PricePoint.joins(ai_model: :provider)
                     .where.not(source: [ nil, "" ])
                     .pluck("price_points.source", "price_points.ai_model_id", "providers.name")

    sources = rows.group_by { |source, _, _| source }.map do |source, points|
      {
        source:       source,
        price_points: points.size,
        models:       points.map { |_, model_id, _| model_id }.uniq.size,
        providers:    points.map { |_, _, provider_name| provider_name }.uniq.sort
      }
    end

    @groups = GROUPS.filter_map do |group|
      entries = sources.select { |s| bucket_for(s[:source]) == group[:key] }
                       .sort_by { |s| [ -s[:price_points], s[:source] ] }
      group.merge(sources: entries) if entries.any?
    end

    @price_point_count = rows.size
    @source_count      = sources.size
    @provider_count    = rows.map(&:last).uniq.size
  end

  private

  def bucket_for(source)
    domain = source[%r{\A[^/]+}].to_s.downcase
    return :community   if COMMUNITY_DOMAINS.include?(domain)
    return :third_party if THIRD_PARTY_DOMAINS.include?(domain)

    :first_party
  end
end
