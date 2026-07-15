module OpenRouter
  # Presents a ModelSync::Result two ways: the Slack Block Kit payload for the
  # team's #token-price channel, and the public social launch posts (which also
  # look up each launched model's description to read like news).
  #
  #   digest = OpenRouter::SyncDigest.new(result)
  #   payload = digest.to_slack_payload   # => Hash or nil (nothing changed)
  #   digest.launch_posts                 # => Array<String>
  class SyncDigest
    BASE_URL = "https://tokenprice.fyi"

    # Slack rejects a message ("invalid_blocks", HTTP 400) once a section block's
    # text exceeds 3000 characters, and separately once a message has more than 50
    # blocks. LINE_PACK_LIMIT keeps each chunk's line content under budget, leaving
    # headroom so the bold group header (merged into the first chunk) and the "see
    # all" trailer (merged into the last chunk) don't push a block past 3000 chars.
    # MAX_BLOCKS keeps the whole message under the block-count limit.
    LINE_PACK_LIMIT = 2700
    MAX_BLOCKS       = 50

    # An OpenRouter import carries no signal for whether a launch is notable or
    # long tail, so the curated provider set is the gate for the social posts.
    # Display names match the seeded major providers.
    ANNOUNCEABLE_PROVIDERS = Set[
      "Anthropic", "OpenAI", "Google", "xAI", "DeepSeek",
      "Meta", "Mistral", "Cohere", "Alibaba", "Moonshot AI"
    ].freeze

    def initialize(result, date: Date.current)
      @result = result
      @date   = date
    end

    # Returns the Slack payload Hash, or nil if nothing changed.
    def to_slack_payload
      sections = []
      sections.concat(price_moves_section) if @result.repriced_records.any?
      sections.concat(new_models_section)  if @result.created_records.any?
      return nil if sections.empty?

      blocks = [ header_block, *sections ]
      if blocks.size > MAX_BLOCKS
        Rails.logger.warn("OpenRouter::SyncDigest: #{blocks.size} blocks built, " \
                           "truncating to Slack's #{MAX_BLOCKS}-block limit")
        blocks = blocks.first(MAX_BLOCKS)
      end

      { text: "Token Price sync — #{@date.strftime('%-d %b %Y')}", blocks: blocks }
    end

    # Below this, drop the description rather than post a stub fragment.
    MIN_BLURB_CHARS = 20

    # Social-post strings for the sync's new launches, one per announceable model.
    # Each carries the model's one-line description (the sync writes one on import)
    # so the post reads like news rather than a bare price line.
    def launch_posts
      records = @result.created_records
        .select { |r| ANNOUNCEABLE_PROVIDERS.include?(r.provider_name) }
      blurbs = AiModel.where(slug: records.map(&:model_slug)).pluck(:slug, :description).to_h
      records.map { |r| launch_post(r, blurbs[r.model_slug]) }
    end

    # Total new models this run, announceable or not — lets the caller log how
    # many launches were filtered below the provider bar.
    def created_count = @result.created_records.size

    private

    def launch_post(record, description)
      headline = "New model: #{record.model_name} (#{record.provider_name}) — " \
                 "$#{fmt(record.input_per_mtok)}/M in, $#{fmt(record.output_per_mtok)}/M out."
      link = "#{BASE_URL}/models/#{record.model_slug}"
      # Two blank-line separators (4 chars) join the up-to-three parts.
      budget = SocialBroadcast::CHAR_LIMIT - headline.length - link.length - 4
      [ headline, fit_blurb(description, budget), link ].compact.join("\n\n")
    end

    # The description, squished onto one line (a multi-line upstream blurb would
    # break the paragraph structure) and trimmed to the budget left after the
    # headline and link — dropped entirely when there's too little room.
    def fit_blurb(description, budget)
      blurb = description.to_s.squish.presence
      return if blurb.nil? || budget < MIN_BLURB_CHARS

      blurb.truncate(budget, omission: "…")
    end

    def header_block
      { type: "header",
        text: { type: "plain_text", text: "Token Price · #{@date.strftime('%-d %b %Y')}" } }
    end

    # Returns one or more mrkdwn section blocks (chunked to stay under Slack's
    # per-block character limit — see LINE_PACK_LIMIT).
    def price_moves_section
      lines   = @result.repriced_records.map { |r| price_move_line(r) }
      header  = "*💰 Price moves (#{lines.size})*"
      trailer = slack_link("#{BASE_URL}/changes", "See all recent price changes →")
      pack_blocks(lines, header: header, trailer: trailer)
    end

    def price_move_line(r)
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

    def new_models_section
      lines  = @result.created_records.map { |r| new_model_line(r) }
      header = "*🆕 New models (#{lines.size})*"
      pack_blocks(lines, header: header)
    end

    def new_model_line(r)
      edit_link    = slack_link("#{BASE_URL}/admin/models/#{r.model_slug}/edit", "edit")
      provider_str = r.new_provider ? "*#{r.provider_name} — new provider ★*" : r.provider_name
      price_str    = "$#{fmt(r.input_per_mtok)}/$#{fmt(r.output_per_mtok)} per MTok"
      "• #{r.model_name} (#{provider_str}) — #{price_str} · #{edit_link}"
    end

    # Packs `lines` into one or more mrkdwn section blocks. `header` is merged
    # into the first block and `trailer` (if given) into the last, so a single
    # line long enough to fill a block on its own can never overflow either.
    def pack_blocks(lines, header:, trailer: nil)
      chunks = pack_lines(lines)
      chunks.each_with_index.map do |chunk, i|
        parts = []
        parts << header if i.zero?
        parts.concat(chunk)
        parts << trailer if trailer && i == chunks.size - 1
        mrkdwn_section(parts.join("\n"))
      end
    end

    # Groups lines into chunks whose newline-joined length stays under
    # LINE_PACK_LIMIT. A single line longer than the limit (e.g. an unusually
    # long model name) is truncated with an ellipsis rather than dropped.
    def pack_lines(lines)
      chunks  = []
      current = []
      length  = 0

      lines.each do |line|
        line = truncate_line(line)
        # +1 accounts for the "\n" that joins this line to the previous one.
        added = current.empty? ? line.length : line.length + 1
        if current.any? && length + added > LINE_PACK_LIMIT
          chunks << current
          current = [ line ]
          length  = line.length
        else
          current << line
          length  += added
        end
      end
      chunks << current if current.any?
      chunks
    end

    def truncate_line(line)
      return line if line.length <= LINE_PACK_LIMIT

      line[0, LINE_PACK_LIMIT - 1] + "…"
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
