# Plain-string USD-per-Mtok formatting, shared by the view helper (which wraps
# the result in HTML / em-dash markup) and price-insight services (which need a
# bare string). Keeping the numeric rule in one place stops the two from
# drifting apart.
module PriceFormat
  module_function

  # Sub-dollar: up to `decimals` places with trailing zeros trimmed ("0.435").
  # Dollar-plus: 2 decimals ("12.50"). Zero collapses to "0". Callers decide
  # how to present nil (em-dash vs "$0"); nil here formats as "0".
  #
  # `decimals` defaults to 4 — the resolution per-1M-token rates need. The raw-USD
  # per-image / per-request dimensions are quoted far smaller (a per-image
  # surcharge like $0.00153), so those callers pass `decimals: 6` to match the
  # stored scale instead of truncating to "$0.0015".
  def usd_amount(value, decimals: 4)
    value = value.to_f
    if value.zero?
      "0"
    elsif value < 1
      format("%.#{decimals}f", value).sub(/0+$/, "").sub(/\.$/, "")
    else
      format("%.2f", value)
    end
  end
end
