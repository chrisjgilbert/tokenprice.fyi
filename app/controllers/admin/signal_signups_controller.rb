require "csv"

module Admin
  # Read-only visibility into the demand-probe signups. The measure-interest
  # opt-in rate is the V1 gate metric, so the owner needs to see it and be able
  # to export it. No editing, importing, or sending happens here.
  class SignalSignupsController < BaseController
    RECENT_LIMIT = 200

    def index
      @counts = SignalSignup.group(:kind).count
      @measure_interest_count = @counts["measure_interest"] || 0
      @price_alert_count      = @counts["price_alert"] || 0
      @signups = SignalSignup.order(created_at: :desc).limit(RECENT_LIMIT)
    end

    def export
      csv = CSV.generate do |out|
        out << %w[kind email payload created_at]
        # find_each bounds memory (the public capture table can grow); cells are
        # neutralized against spreadsheet formula injection since email/payload
        # are attacker-supplied.
        SignalSignup.find_each do |signup|
          out << [ csv_safe(signup.kind), csv_safe(signup.email), csv_safe(signup.payload), signup.created_at.iso8601 ]
        end
      end

      filename = "signal_signups_#{Time.current.strftime('%Y%m%d')}.csv"
      send_data csv, type: "text/csv", filename: filename, disposition: "attachment"
    end

    private

    # Neutralize spreadsheet formula injection: quote any cell that begins with a
    # formula trigger (= + - @), including after leading whitespace/newlines
    # (some apps trim those before evaluating), or with a leading tab/CR/LF.
    # payload is free-form and attacker-supplied, so the check can't assume the
    # trigger sits at position 0.
    def csv_safe(value)
      string = value.to_s
      dangerous = string.match?(/\A[\t\r\n]/) || string.lstrip.match?(/\A[=+\-@]/)
      dangerous ? "'#{string}" : string
    end
  end
end
