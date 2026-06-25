module OpenRouter
  # Formats a ModelSync::Result into a Slack Block Kit payload for posting
  # to the team's #token-price channel.
  #
  #   digest = OpenRouter::SyncDigest.new(result)
  #   payload = digest.to_slack_payload   # => Hash or nil (nothing changed)
  class SyncDigest
    BASE_URL = "https://tokenprice.fyi"

    def initialize(result, date: Date.current)
      @result = result
      @date   = date
    end

    # Returns the Slack payload Hash, or nil if nothing changed.
    def to_slack_payload
      sections = []
      sections << price_moves_section if @result.repriced_records.any?
      sections << new_models_section  if @result.created_records.any?
      return nil if sections.empty?

      { text: "Token Price sync — #{@date.strftime('%-d %b %Y')}",
        blocks: [ header_block, *sections ] }
    end

    private

    def header_block
      { type: "header",
        text: { type: "plain_text", text: "Token Price · #{@date.strftime('%-d %b %Y')}" } }
    end

    def price_moves_section
      lines = @result.repriced_records.map do |r|
        model_link = slack_link("#{BASE_URL}/models/#{r.model_slug}", r.model_name)
        edit_link  = slack_link("#{BASE_URL}/admin/models/#{r.model_slug}/edit", "edit")
        pct        = r.pct_input_change
        sign       = pct >= 0 ? "+" : ""
        cached_str = (r.old_cached || r.new_cached) ?
          ", $#{fmt(r.old_cached)}→$#{fmt(r.new_cached)} cached" : ""
        "• #{model_link} (#{r.provider_name}) — " \
          "$#{fmt(r.old_input)}→$#{fmt(r.new_input)} in, " \
          "$#{fmt(r.old_output)}→$#{fmt(r.new_output)} out#{cached_str} · " \
          "#{sign}#{pct}% input · #{edit_link}"
      end
      mrkdwn_section("*💰 Price moves (#{lines.size})*\n#{lines.join("\n")}")
    end

    def new_models_section
      lines = @result.created_records.map do |r|
        edit_link    = slack_link("#{BASE_URL}/admin/models/#{r.model_slug}/edit", "edit")
        provider_str = r.new_provider ? "*#{r.provider_name} — new provider ★*" : r.provider_name
        "• #{r.model_name} (#{provider_str}) — " \
          "$#{fmt(r.input_per_mtok)}/$#{fmt(r.output_per_mtok)} per MTok · #{edit_link}"
      end
      mrkdwn_section("*🆕 New models (#{lines.size})*\n#{lines.join("\n")}")
    end

    def mrkdwn_section(text)
      { type: "section", text: { type: "mrkdwn", text: text } }
    end

    def slack_link(url, text) = "<#{url}|#{text}>"

    def fmt(value)
      return "0" if value.nil? || value.zero?
      # Four decimal places preserves sub-cent prices (e.g. $0.003 cached); strip trailing zeros.
      sprintf("%.4f", value.to_f).sub(/\.?0+$/, "")
    end
  end
end
