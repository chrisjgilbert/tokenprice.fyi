# Phase 2 of docs/HISTORICAL_BACKFILL.md: mine the git history of BerriAI/litellm's
# model_prices_and_context_window.json — a community-maintained price catalog whose
# commit log is a dated record of price changes since September 2023 — for changes
# our seed misses.
#
# Needs a blob-less probe clone (cheap; blobs are fetched lazily over the network
# as each historical snapshot is read):
#
#   git clone --filter=blob:none --no-checkout https://github.com/BerriAI/litellm /tmp/litellm-probe
#
# Point LITELLM_CLONE elsewhere if yours lives somewhere else. The output,
# docs/backfill/litellm_price_changes.md, is a review artifact, not a DB import —
# a LiteLLM commit proves a price changed *by* that week, not *on* it, so every
# candidate gets confirmed against first-party sources before touching db/seeds.rb.
namespace :backfill do
  desc "Mine LiteLLM pricing-file history for missed price changes (writes docs/backfill/litellm_price_changes.md)"
  task :litellm_history do
    require "json"
    require "date"
    require "open3"

    pricing_file = "model_prices_and_context_window.json"
    clone        = ENV.fetch("LITELLM_CLONE", "/tmp/litellm-probe")
    artifact     = File.expand_path("../../docs/backfill/litellm_price_changes.md", __dir__)

    # LiteLLM id => our seed slug (AiModel#slug, i.e. name.parameterize), kept in
    # sync with db/seeds.rb by hand. Ordered: for each slug, the first id present
    # in a snapshot wins, so marketing aliases lead and dated snapshot ids act as
    # fallbacks for eras before/after the alias existed. Google ids use the
    # "gemini/" prefix (AI Studio pricing) — the bare ids are Vertex.
    #
    # Seed models with no usable LiteLLM id (verified against HEAD, 2026-06-11):
    #   deepseek-v4-pro, deepseek-v4-flash — direct-API ids never added (only a
    #     third-party tensormesh host entry exists)
    #   qwen-3-7-max       — Qwen 3.7 Max not in the catalog
    #   grok-build-0-1     — not in the catalog
    #   mistral-medium-3-5 — no distinct id; mistral-medium-latest drifts across
    #     generations, so it can't be pinned to one of our models
    #   mistral-small-4    — same problem as mistral-medium-3-5
    mapping = {
      # ---- Anthropic ------------------------------------------------------
      "claude-fable-5"             => "claude-fable-5",
      "claude-opus-4-8"            => "claude-opus-4-8",
      "claude-opus-4-7"            => "claude-opus-4-7",
      "claude-opus-4-7-20260416"   => "claude-opus-4-7",
      "claude-opus-4-6"            => "claude-opus-4-6",
      "claude-opus-4-6-20260205"   => "claude-opus-4-6",
      "claude-opus-4-5"            => "claude-opus-4-5",
      "claude-opus-4-5-20251101"   => "claude-opus-4-5",
      "claude-opus-4-1"            => "claude-opus-4-1",
      "claude-opus-4-1-20250805"   => "claude-opus-4-1",
      "claude-opus-4-20250514"     => "claude-opus-4",
      "claude-4-opus-20250514"     => "claude-opus-4",
      "claude-sonnet-4-6"          => "claude-sonnet-4-6",
      "claude-sonnet-4-5"          => "claude-sonnet-4-5",
      "claude-sonnet-4-5-20250929" => "claude-sonnet-4-5",
      "claude-sonnet-4-20250514"   => "claude-sonnet-4",
      "claude-4-sonnet-20250514"   => "claude-sonnet-4",
      "claude-haiku-4-5"           => "claude-haiku-4-5",
      "claude-haiku-4-5-20251001"  => "claude-haiku-4-5",
      "claude-3-5-sonnet-20241022" => "claude-3-5-sonnet",
      "claude-3-5-sonnet-20240620" => "claude-3-5-sonnet",
      "claude-3-5-sonnet-latest"   => "claude-3-5-sonnet",
      "claude-3-5-haiku-20241022"  => "claude-3-5-haiku",
      "claude-3-5-haiku-latest"    => "claude-3-5-haiku",
      "claude-3-opus-20240229"     => "claude-3-opus",
      "claude-3-sonnet-20240229"   => "claude-3-sonnet",
      "claude-3-haiku-20240307"    => "claude-3-haiku",

      # ---- OpenAI ---------------------------------------------------------
      "gpt-5.5-pro"        => "gpt-5-5-pro",
      "gpt-5.5"            => "gpt-5-5",
      "gpt-5"              => "gpt-5",
      "o3"                 => "o3",
      "gpt-4.1"            => "gpt-4-1",
      "o4-mini"            => "o4-mini",
      "gpt-4.1-mini"       => "gpt-4-1-mini",
      "gpt-4.1-nano"       => "gpt-4-1-nano",
      "o3-mini"            => "o3-mini",
      "gpt-4.5-preview"    => "gpt-4-5",
      "o1"                 => "o1",
      "o1-mini"            => "o1-mini",
      "o1-preview"         => "o1-preview",
      "gpt-4o-mini"        => "gpt-4o-mini",
      "gpt-4o"             => "gpt-4o",
      "gpt-4-turbo"        => "gpt-4-turbo",
      "gpt-4-1106-preview" => "gpt-4-turbo",
      "gpt-4"              => "gpt-4",

      # ---- Google (AI Studio "gemini/" ids, not Vertex) --------------------
      "gemini/gemini-3.1-pro-preview" => "gemini-3-1-pro",
      "gemini/gemini-3-pro-preview"   => "gemini-3-pro",
      "gemini/gemini-2.5-pro"         => "gemini-2-5-pro",
      "gemini/gemini-3.5-flash"       => "gemini-3-5-flash",
      "gemini/gemini-3-flash-preview" => "gemini-3-flash",
      "gemini/gemini-2.5-flash"       => "gemini-2-5-flash",
      "gemini/gemini-2.0-flash"       => "gemini-2-0-flash",
      "gemini/gemini-2.0-flash-001"   => "gemini-2-0-flash",
      "gemini/gemini-1.5-pro"         => "gemini-1-5-pro",
      "gemini/gemini-1.5-flash"       => "gemini-1-5-flash",
      "gemini/gemini-pro"             => "gemini-1-0-pro",

      # ---- xAI ------------------------------------------------------------
      "xai/grok-4.3"                  => "grok-4-3",
      "xai/grok-4.20-0309-reasoning"  => "grok-4-20",
      "xai/grok-4.20-beta-0309-reasoning" => "grok-4-20",
      "xai/grok-4"                    => "grok-4",
      "xai/grok-4-0709"               => "grok-4",
      "xai/grok-4-1-fast-reasoning"   => "grok-4-1-fast",
      "xai/grok-4-1-fast"             => "grok-4-1-fast",
      "xai/grok-3-mini"               => "grok-3-mini",
      "xai/grok-3-mini-beta"          => "grok-3-mini",
      "xai/grok-2-1212"               => "grok-2",
      "xai/grok-2"                    => "grok-2",
      "xai/grok-beta"                 => "grok-2",

      # ---- DeepSeek (the -chat/-reasoner aliases are the direct API) -------
      "deepseek/deepseek-chat"     => "deepseek-v3",
      "deepseek-chat"              => "deepseek-v3",
      "deepseek/deepseek-reasoner" => "deepseek-r1",
      "deepseek-reasoner"          => "deepseek-r1",

      # ---- Open-weight (hosted rates — one representative provider) --------
      "deepinfra/meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8"   => "llama-4-maverick",
      "together_ai/meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8" => "llama-4-maverick",
      "deepinfra/meta-llama/Llama-4-Scout-17B-16E-Instruct"           => "llama-4-scout",
      "together_ai/meta-llama/Llama-4-Scout-17B-16E-Instruct"         => "llama-4-scout",
      "together_ai/meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo"     => "llama-3-1-405b",
      "openrouter/meta-llama/llama-3-70b-instruct"                    => "llama-3-70b",

      # ---- Mistral ----------------------------------------------------------
      "mistral/mistral-large-3"    => "mistral-large-3",
      "mistral/mistral-large-2512" => "mistral-large-3",
      "mistral/mistral-large-2407" => "mistral-large-2",
      "mistral/mistral-large-2402" => "mistral-large",

      # ---- Alibaba / Moonshot ----------------------------------------------
      "dashscope/qwen3-max"            => "qwen3-max",
      "dashscope/qwen3-max-2026-01-23" => "qwen3-max",
      "moonshot/kimi-k2.6"             => "kimi-k2-6",
      "moonshot/kimi-k2.5"             => "kimi-k2-5",
      "moonshot/kimi-k2-0711-preview"  => "kimi-k2"
    }.freeze

    # Release dates from db/seeds.rb. Readings before a model existed are alias
    # bleed-through (e.g. deepseek-chat carried V2.5 pricing before V3 shipped,
    # xai/grok-beta predates the grok-2 ids) and would fake a launch-day "change".
    released = {
      "claude-fable-5" => "2026-06-09", "claude-opus-4-8" => "2026-05-28",
      "claude-opus-4-7" => "2026-04-16", "claude-opus-4-6" => "2026-02-05",
      "claude-opus-4-5" => "2025-11-24", "claude-opus-4-1" => "2025-08-05",
      "claude-opus-4" => "2025-05-22", "claude-sonnet-4-6" => "2026-02-17",
      "claude-sonnet-4-5" => "2025-09-29", "claude-sonnet-4" => "2025-05-22",
      "claude-haiku-4-5" => "2025-10-15", "claude-3-5-sonnet" => "2024-06-20",
      "claude-3-5-haiku" => "2024-10-22", "claude-3-opus" => "2024-03-04",
      "claude-3-sonnet" => "2024-03-04", "claude-3-haiku" => "2024-03-04",
      "gpt-5-5-pro" => "2026-04-24", "gpt-5-5" => "2026-04-23",
      "gpt-5" => "2025-08-07", "o3" => "2025-04-16", "gpt-4-1" => "2025-04-14",
      "o4-mini" => "2025-04-16", "gpt-4-1-mini" => "2025-04-14",
      "gpt-4-1-nano" => "2025-04-14", "o3-mini" => "2025-01-31",
      "gpt-4-5" => "2025-02-27", "o1" => "2024-12-17", "o1-mini" => "2024-09-12",
      "o1-preview" => "2024-09-12", "gpt-4o-mini" => "2024-07-18",
      "gpt-4o" => "2024-05-13", "gpt-4-turbo" => "2023-11-06", "gpt-4" => "2023-03-14",
      "gemini-3-1-pro" => "2026-02-19", "gemini-3-pro" => "2025-11-18",
      "gemini-2-5-pro" => "2025-06-17", "gemini-3-5-flash" => "2026-05-19",
      "gemini-3-flash" => "2025-12-17", "gemini-2-5-flash" => "2025-06-17",
      "gemini-2-0-flash" => "2024-12-11", "gemini-1-5-pro" => "2024-02-15",
      "gemini-1-5-flash" => "2024-05-14", "gemini-1-0-pro" => "2023-12-06",
      "grok-4-3" => "2026-04-30", "grok-4-20" => "2026-03-10",
      "grok-4" => "2025-07-09", "grok-4-1-fast" => "2025-11-19",
      "grok-3-mini" => "2025-06-10", "grok-2" => "2024-08-13",
      "deepseek-r1" => "2025-01-20", "deepseek-v3" => "2024-12-26",
      "llama-4-maverick" => "2025-04-05", "llama-4-scout" => "2025-04-05",
      "llama-3-1-405b" => "2024-07-23", "llama-3-70b" => "2024-04-18",
      "mistral-large-3" => "2025-12-02", "mistral-large-2" => "2024-07-24",
      "mistral-large" => "2024-02-26", "qwen3-max" => "2025-09-23",
      "kimi-k2-6" => "2026-04-20", "kimi-k2-5" => "2026-01-27", "kimi-k2" => "2025-07-11"
    }.transform_values { |d| Date.parse(d) }.freeze

    abort "No clone at #{clone} — see the comment atop this file" unless File.directory?(File.join(clone, ".git"))

    git = ->(*args) do
      out, err, status = Open3.capture3("git", "-C", clone, *args)
      [out, err, status.success?]
    end

    # Sample the history: last commit per ISO week is plenty — prices don't flap.
    log, err, ok = git.call("log", "--format=%H %cs", "--reverse", "--", pricing_file)
    abort "git log failed: #{err}" unless ok
    commits = log.lines.map(&:split)
    samples = commits.each_with_object({}) do |(sha, date), weeks|
      d = Date.parse(date)
      weeks[[d.cwyear, d.cweek]] = [sha, d] # chronological input — last in week wins
    end.values
    puts "#{commits.size} commits touching #{pricing_file}; sampling #{samples.size} weekly snapshots (#{samples.first.last} → #{samples.last.last})"

    # Per-MTok prices for one snapshot, keyed by our slug. First mapped id present
    # wins; entries that aren't chat models or carry no token prices are ignored.
    per_mtok = ->(entry, key) { (v = entry[key]) && (v * 1_000_000).round(6) }
    extract = ->(json) do
      mapping.each_with_object({}) do |(id, slug), readings|
        next if readings.key?(slug)
        entry = json[id]
        next unless entry.is_a?(Hash)
        next if entry["mode"] && !%w[chat completion responses].include?(entry["mode"])
        # A few entries (e.g. dashscope/qwen3-max) moved to tiered pricing —
        # read the lowest tier so the series stays comparable.
        priced = entry["input_cost_per_token"] ? entry : (entry["tiered_pricing"] || []).first || {}
        input, output, cached = %w[input_cost_per_token output_cost_per_token cache_read_input_token_cost]
          .map { |k| per_mtok.call(priced.merge(entry.slice("cache_read_input_token_cost")), k) }
        next unless input && output
        readings[slug] = { in: input, out: output, cached: cached, id: id }
      end
    end

    skipped  = [] # [date, reason]
    current  = {} # slug => last reading
    rows     = Hash.new { |h, k| h[k] = [] } # slug => artifact table rows
    fmt      = ->(v) { v.nil? ? "—" : format("%g", v) }
    delta    = ->(a, b, key) { a[key] == b[key] ? fmt.call(b[key]) : "#{fmt.call(a[key])} → #{fmt.call(b[key])}" }

    samples.each_with_index do |(sha, date), i|
      print "\r[#{i + 1}/#{samples.size}] #{date} #{sha[0, 10]}   "
      blob, err, ok = git.call("show", "#{sha}:#{pricing_file}")
      unless ok
        warn "\nWARN #{date}: blob fetch failed (#{err.lines.first&.strip}) — skipping"
        skipped << [date, "fetch failed"]
        next
      end
      begin
        json = JSON.parse(blob)
      rescue JSON::ParserError => e
        warn "\nWARN #{date}: malformed JSON (#{e.message[0, 60]}) — skipping"
        skipped << [date, "malformed JSON"]
        next
      end

      extract.call(json).each do |slug, reading|
        next if released[slug] && date < released[slug] - 7 # alias bleed-through guard
        prev = current[slug]
        if prev.nil?
          rows[slug] << "| #{date} | first seen | #{fmt.call(reading[:in])} | #{fmt.call(reading[:out])} | #{fmt.call(reading[:cached])} | `#{reading[:id]}` |"
        elsif reading.values_at(:in, :out, :cached) != prev.values_at(:in, :out, :cached)
          rows[slug] << "| #{prev[:date]} → #{date} | change | #{delta.call(prev, reading, :in)} | #{delta.call(prev, reading, :out)} | #{delta.call(prev, reading, :cached)} | `#{reading[:id]}` |"
        end
        current[slug] = reading.merge(date: date)
      end
    end
    puts

    # Preserve the hand-curated analysis section across reruns.
    candidates_block = if File.exist?(artifact) && File.read(artifact) =~ /(<!-- BEGIN CANDIDATES -->.*<!-- END CANDIDATES -->)/m
      Regexp.last_match(1)
    else
      "<!-- BEGIN CANDIDATES -->\n_To be filled in by hand after reviewing the change log below._\n<!-- END CANDIDATES -->"
    end

    head_sha, = git.call("rev-parse", "HEAD")
    out = +"# LiteLLM price-history mining — review artifact\n\n"
    out << "Generated by `rake backfill:litellm_history` on #{Date.today} from #{clone} "
    out << "(HEAD `#{head_sha.strip[0, 12]}`). Sampled #{samples.size - skipped.size} of #{samples.size} weekly "
    out << "snapshots (#{commits.size} commits, #{samples.first.last} → #{samples.last.last})"
    out << (skipped.empty? ? ".\n" : "; skipped #{skipped.size}: #{skipped.map { |d, r| "#{d} (#{r})" }.join(', ')}.\n")
    out << <<~PREAMBLE

      Prices are USD per MTok (input / output / cached input), read from the lowest
      tier where the entry is context-tiered. A change appearing in the window
      `A → B` means LiteLLM recorded it between those weekly snapshots — the real
      effective date needs first-party confirmation (see docs/HISTORICAL_BACKFILL.md,
      "Pitfalls"). Open-weight models reflect a single representative host, so their
      moves are host repricing, not vendor announcements.

      ## Candidate missed price changes

      #{candidates_block}

      ## Change log by model

    PREAMBLE
    mapping.values.uniq.each do |slug|
      next if rows[slug].empty?
      out << "### #{slug}\n\n"
      out << "| Window | Event | In $/MTok | Out $/MTok | Cached $/MTok | LiteLLM id |\n"
      out << "|---|---|---|---|---|---|\n"
      out << rows[slug].join("\n") << "\n\n"
    end
    missing = mapping.values.uniq - rows.keys
    out << "_Mapped but never seen in the sampled history: #{missing.map { |s| "`#{s}`" }.join(', ')}._\n" if missing.any?

    require "fileutils"
    FileUtils.mkdir_p(File.dirname(artifact))
    File.write(artifact, out)
    puts "Wrote #{artifact} (#{rows.values.sum(&:size)} rows across #{rows.size} models)"
  end
end
