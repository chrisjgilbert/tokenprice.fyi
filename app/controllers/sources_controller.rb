class SourcesController < ApplicationController
  # Every PricePoint stores a bare source string ("anthropic.com/pricing",
  # "openrouter.ai", "scmp.com"). The attribution table buckets each one by its
  # leading domain. First-party means the provider's own pricing page or
  # announcement, recognised via the providers' website hosts (plus the few
  # first-party domains that don't match, like Alibaba's cloud docs). Anything
  # unrecognised lands in third-party — on an attribution page, mislabelling a
  # press source as a provider's own page is the worse failure.
  FIRST_PARTY_EXTRA_DOMAINS = %w[
    alibabacloud.com
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

    first_party = first_party_domains
    @groups = GROUPS.filter_map do |group|
      entries = sources.select { |s| bucket_for(s[:source], first_party) == group[:key] }
                       .sort_by { |s| [ -s[:price_points], s[:source] ] }
      group.merge(sources: entries) if entries.any?
    end

    @price_point_count = rows.size
    @source_count      = sources.size
    @provider_count    = rows.map(&:last).uniq.size
  end

  private

  # The hosts of the providers' own websites ("www.anthropic.com" → "anthropic.com"),
  # so "docs.x.ai" or "api-docs.deepseek.com" count as first-party by suffix.
  def first_party_domains
    hosts = Provider.pluck(:website).filter_map do |website|
      URI.parse(website.to_s).host&.downcase&.delete_prefix("www.")
    rescue URI::InvalidURIError
      nil
    end
    hosts + FIRST_PARTY_EXTRA_DOMAINS
  end

  def bucket_for(source, first_party)
    domain = source[%r{\A[^/]+}].to_s.downcase
    return :community   if domain_under?(domain, COMMUNITY_DOMAINS)
    return :first_party if domain_under?(domain, first_party)

    :third_party
  end

  def domain_under?(domain, domains)
    domains.any? { |d| domain == d || domain.end_with?(".#{d}") }
  end
end
