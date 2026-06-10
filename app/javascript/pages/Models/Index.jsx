import { useCallback, useMemo, useRef, useState } from "react"
import { AgGridReact } from "ag-grid-react"
import { AllCommunityModule, ModuleRegistry, themeQuartz } from "ag-grid-community"

ModuleRegistry.registerModules([AllCommunityModule])

// Mirrors ApplicationHelper#usd: sub-dollar prices keep more precision
// (DeepSeek is $0.435); dollar-plus prices show cents.
function usd(value) {
  if (value == null) return "—"
  if (value === 0) return "$0"
  if (value < 1) return `$${value.toFixed(4).replace(/0+$/, "").replace(/\.$/, "")}`
  return `$${value.toFixed(2)}`
}

// Mirrors ApplicationHelper#tokens_short: 1_000_000 -> "1M", 200_000 -> "200K".
function tokensShort(count) {
  if (count == null) return "—"
  if (count >= 1_000_000) return `${String(Math.round((count / 1_000_000) * 100) / 100)}M`
  if (count >= 1_000) return `${Math.floor(count / 1_000)}K`
  return String(count)
}

function monthYear(isoDate) {
  if (!isoDate) return "—"
  return new Date(isoDate).toLocaleDateString("en-US", {
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  })
}

const TIERS = [
  { label: "All", value: null },
  { label: "Frontier", value: "frontier" },
  { label: "Mid", value: "mid" },
  { label: "Small / fast", value: "small" },
]

const TIER_STYLES = {
  frontier: "bg-indigo-50 text-indigo-700 ring-indigo-600/20",
  mid: "bg-sky-50 text-sky-700 ring-sky-600/20",
  small: "bg-amber-50 text-amber-700 ring-amber-600/20",
}

const TIER_LABELS = { frontier: "Frontier", mid: "Mid", small: "Small / fast" }

function TierBadge({ value }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset ${TIER_STYLES[value] ?? "bg-slate-50 text-slate-600 ring-slate-500/20"}`}
    >
      {TIER_LABELS[value] ?? value}
    </span>
  )
}

function ModelCell({ data }) {
  return (
    <span className="inline-flex items-center gap-1.5">
      <a href={data.url} className="font-medium text-slate-900 hover:text-indigo-600">
        {data.name}
      </a>
      {data.status !== "active" && (
        <span className="inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-xs font-medium text-slate-500 capitalize">
          {data.status}
        </span>
      )}
    </span>
  )
}

function ProviderCell({ data }) {
  return (
    <a href={data.providerUrl} className="text-slate-600 hover:underline">
      {data.provider}
    </a>
  )
}

// Match the app's slate/indigo Tailwind palette.
const gridTheme = themeQuartz.withParams({
  accentColor: "#4f46e5",
  borderColor: "#e2e8f0",
  headerBackgroundColor: "#f8fafc",
  headerTextColor: "#64748b",
  fontFamily: "inherit",
  headerFontWeight: 500,
  rowHoverColor: "#f8fafc",
  wrapperBorderRadius: "0.75rem",
})

const numberColumn = {
  type: "rightAligned",
  filter: "agNumberColumnFilter",
  cellClass: "tabular-nums text-right",
}

export default function Index({ models, cheapestFrontier }) {
  const gridRef = useRef(null)
  const [quickFilter, setQuickFilter] = useState("")
  const [tier, setTier] = useState(null)
  const [visibleCount, setVisibleCount] = useState(models.length)

  const columnDefs = useMemo(
    () => [
      { field: "name", headerName: "Model", cellRenderer: ModelCell, flex: 2, minWidth: 220 },
      { field: "provider", headerName: "Provider", cellRenderer: ProviderCell, minWidth: 130 },
      {
        field: "tier",
        headerName: "Tier",
        cellRenderer: TierBadge,
        minWidth: 120,
      },
      {
        field: "input",
        headerName: "Input",
        ...numberColumn,
        valueFormatter: (p) => usd(p.value),
      },
      {
        field: "output",
        headerName: "Output",
        ...numberColumn,
        valueFormatter: (p) => usd(p.value),
      },
      {
        field: "cachedInput",
        headerName: "Cached in",
        ...numberColumn,
        cellClass: "tabular-nums text-right text-slate-500",
        valueFormatter: (p) => usd(p.value),
      },
      {
        field: "contextWindow",
        headerName: "Context",
        ...numberColumn,
        cellClass: "tabular-nums text-right text-slate-500",
        valueFormatter: (p) => tokensShort(p.value),
      },
      {
        field: "blended",
        headerName: "Blended",
        headerTooltip: "Blended $/1M tokens at a 3:1 input:output mix",
        ...numberColumn,
        cellClass: "tabular-nums text-right font-semibold",
        sort: "asc",
        valueFormatter: (p) => usd(p.value),
      },
      {
        field: "releasedOn",
        headerName: "Released",
        type: "rightAligned",
        filter: "agDateColumnFilter",
        cellClass: "tabular-nums text-right text-slate-500",
        valueGetter: (p) => (p.data.releasedOn ? new Date(p.data.releasedOn) : null),
        valueFormatter: (p) => monthYear(p.data.releasedOn),
      },
    ],
    []
  )

  const defaultColDef = useMemo(
    () => ({
      sortable: true,
      filter: "agTextColumnFilter",
      floatingFilter: true,
      resizable: false,
      flex: 1,
      minWidth: 110,
      // Nulls (missing prices/dates) always sort to the bottom.
      comparator: (a, b) => {
        if (a == null && b == null) return 0
        if (a == null) return 1
        if (b == null) return -1
        return a < b ? -1 : a > b ? 1 : 0
      },
    }),
    []
  )

  const applyTier = useCallback((value) => {
    setTier(value)
    const api = gridRef.current?.api
    if (!api) return
    api
      .setColumnFilterModel("tier", value ? { filterType: "text", type: "equals", filter: value } : null)
      .then(() => api.onFilterChanged())
  }, [])

  const onFilterChanged = useCallback(() => {
    const api = gridRef.current?.api
    if (api) setVisibleCount(api.getDisplayedRowCount())
  }, [])

  return (
    <>
      <section className="mb-8">
        <h1 className="text-3xl sm:text-4xl font-bold tracking-tight">
          What does a million tokens cost?
        </h1>
        <p className="mt-3 max-w-2xl text-slate-600">
          Live-ish pricing for every frontier LLM, side by side. Search, filter, and sort by input,
          output, or a blended rate, and see how prices have moved over time.
        </p>
      </section>

      {cheapestFrontier && (
        <a
          href={cheapestFrontier.url}
          className="group mb-8 flex items-center justify-between gap-4 rounded-xl border border-indigo-100 bg-gradient-to-br from-indigo-50 to-white p-5 hover:border-indigo-200"
        >
          <div>
            <p className="text-xs font-semibold uppercase tracking-wide text-indigo-600">
              Cheapest frontier model
            </p>
            <p className="mt-1 text-xl font-semibold">{cheapestFrontier.name}</p>
            <p className="text-sm text-slate-500">
              {cheapestFrontier.provider} · {usd(cheapestFrontier.blended)} blended / 1M tokens
            </p>
          </div>
          <div className="text-right">
            <p className="text-sm text-slate-500">
              in {usd(cheapestFrontier.input)} · out {usd(cheapestFrontier.output)}
            </p>
            <span className="text-sm font-medium text-indigo-600 group-hover:underline">
              View history →
            </span>
          </div>
        </a>
      )}

      <div className="mb-4 flex flex-wrap items-center gap-2 text-sm">
        <label htmlFor="quick-search" className="sr-only">
          Search models and providers
        </label>
        <input
          id="quick-search"
          type="search"
          value={quickFilter}
          onChange={(e) => setQuickFilter(e.target.value)}
          placeholder="Search models or providers…"
          className="w-full sm:w-64 rounded-lg border border-slate-200 bg-white px-3 py-1.5 placeholder:text-slate-400 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        />
        <span className="ml-1 text-slate-500">Tier:</span>
        {TIERS.map(({ label, value }) => (
          <button
            key={label}
            type="button"
            onClick={() => applyTier(value)}
            aria-pressed={tier === value}
            className={`rounded-full px-3 py-1 ring-1 ring-inset ${
              tier === value
                ? "bg-indigo-600 text-white ring-indigo-600"
                : "bg-white text-slate-600 ring-slate-200 hover:bg-slate-100"
            }`}
          >
            {label}
          </button>
        ))}
        <span className="ml-auto text-xs text-slate-500" aria-live="polite">
          {visibleCount === models.length
            ? `${models.length} models`
            : `${visibleCount} of ${models.length} models`}
        </span>
      </div>

      <AgGridReact
        ref={gridRef}
        theme={gridTheme}
        rowData={models}
        columnDefs={columnDefs}
        defaultColDef={defaultColDef}
        quickFilterText={quickFilter}
        onFilterChanged={onFilterChanged}
        domLayout="autoHeight"
        suppressCellFocus
        enableCellTextSelection
        overlayNoRowsTemplate="<span class='text-slate-500'>No models match — clear the search or filters above.</span>"
      />

      <p className="mt-4 text-xs text-slate-500">
        Blended price assumes a 3:1 input-to-output token mix — a rough stand-in for a typical
        chat/agent workload, so models with different input vs output pricing can be ranked on one
        number. Use the filter row under each column header for exact thresholds.
      </p>
    </>
  )
}
