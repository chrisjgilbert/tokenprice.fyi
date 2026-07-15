# Groups lines into chunks that stay under a character budget, for building
# Slack Block Kit mrkdwn section blocks. Slack rejects a section block whose
# text exceeds 3000 characters with HTTP 400 "invalid_blocks", so callers pass
# a limit with headroom under that hard cap (and any room needed for header/
# trailer text they merge into a chunk themselves).
#
#   SlackBlockPacker.pack(lines, limit: 2900)   # => [["line1", "line2"], ["line3"]]
class SlackBlockPacker
  def self.pack(lines, limit:)
    chunks  = []
    current = []
    length  = 0

    lines.each do |line|
      line = truncate(line, limit)
      # +1 accounts for the "\n" that joins this line to the previous one.
      added = current.empty? ? line.length : line.length + 1
      if current.any? && length + added > limit
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

  # A single line longer than the limit (e.g. an unusually long title) is
  # truncated with an ellipsis rather than dropped.
  def self.truncate(line, limit)
    return line if line.length <= limit

    line[0, limit - 1] + "…"
  end
end
