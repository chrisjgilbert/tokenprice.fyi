module WorldMapHelper
  WORLD_MAP_PATH = Rails.root.join("lib/data/world_map.json")

  # Projected (equirectangular) world map: { "viewBox" => "...",
  # "countries" => { "US" => { "name", "d" (SVG path), "cx", "cy" } } }.
  # Memoized per-process — the file is static and read-only.
  def world_map
    @@world_map ||= JSON.parse(File.read(WORLD_MAP_PATH)).freeze
  end

  # Crop the empty polar oceans so inhabited land fills the frame.
  def world_map_viewbox = "0 28 1000 384"

  # Interpolated fill for a country, from a faint base to the full indigo
  # accent as its provider count approaches the busiest country's.
  def country_fill(count, max)
    return "var(--color-slate-200, #e2e8f0)" if count.to_i.zero? || max.to_i.zero?

    t = 0.34 + (0.66 * count.to_f / max)
    "rgba(79, 70, 229, #{t.round(3)})"
  end
end
