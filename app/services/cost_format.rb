# Money / token formatting for the estimator, ported from the design engine's
# self-contained formatters (`money`, `perCallFmt`, `kfmt`, `pct`). Kept in one
# place so the tested engine and the views format identically — the estimator
# equivalent of PriceFormat.
module CostFormat
  module_function

  # Monthly/aggregate dollars: thousands rounded with commas, then progressively
  # more precision as the number shrinks toward sub-cent.
  def money(v)
    v = v.to_f
    if v >= 1000 then "$#{with_commas(v.round)}"
    elsif v >= 100 then format("$%.0f", v)
    elsif v >= 1 then format("$%.2f", v)
    elsif v >= 0.01 then "$#{format('%.3f', v).sub(/0+$/, '').sub(/\.$/, '')}"
    else format("$%.4f", v)
    end
  end

  # Per-request dollars: never collapses to $0 for a tiny positive cost.
  def per_call(v)
    v = v.to_f
    if v >= 1 then format("$%.2f", v)
    elsif v >= 0.01 then format("$%.3f", v)
    elsif v >= 0.0001 then format("$%.4f", v)
    elsif v > 0 then "<$0.0001"
    else "$0"
    end
  end

  # Compact token counts: 1.2M, 450K, 900.
  def kfmt(n)
    n = n.to_i
    if n >= 1_000_000_000 then trim(n / 1_000_000_000.0) + "B"
    elsif n >= 1_000_000 then trim(n / 1_000_000.0) + "M"
    elsif n >= 1_000 then trim(n / 1_000.0) + "K"
    else n.to_s
    end
  end

  # Percentage change from b to a, rounded to a whole number. Negative = cheaper.
  def pct(a, b)
    b.to_f.zero? ? 0 : (((a - b) / b) * 100).round
  end

  def with_commas(int)
    int.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end

  # One decimal place, but only when it isn't a whole number ("1.2" / "12").
  def trim(f)
    f == f.round ? f.round.to_s : format("%.1f", f)
  end
end
