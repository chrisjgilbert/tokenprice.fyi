# Plain-string USD-per-Mtok formatting, shared by the view helper (which wraps
# the result in HTML / em-dash markup) and price-insight services (which need a
# bare string). Keeping the numeric rule in one place stops the two from
# drifting apart.
module PriceFormat
  module_function

  # Sub-dollar: up to 4 decimals with trailing zeros trimmed ("0.435").
  # Dollar-plus: 2 decimals ("12.50"). Zero collapses to "0". Callers decide
  # how to present nil (em-dash vs "$0"); nil here formats as "0".
  def usd_amount(value)
    value = value.to_f
    if value.zero?
      "0"
    elsif value < 1
      format("%.4f", value).sub(/0+$/, "").sub(/\.$/, "")
    else
      format("%.2f", value)
    end
  end
end
