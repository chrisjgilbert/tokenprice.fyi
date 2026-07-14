class BackfillDescriptionGeneratedAt < ActiveRecord::Migration[8.0]
  # Legacy OpenRouter rows were written up before description_generated_at
  # existed, so their generated copy carries a nil stamp — indistinguishable, by
  # timestamp alone, from a hand-written seed row the refresh job must never
  # touch. Stamp them from created_at (when the sync first described them) so the
  # refresh job treats them as generated copy on the normal freshness clock.
  #
  # Only source 'openrouter' rows are backfilled. Manual rows are a mix of
  # hand-written seed editorial (must stay unstamped and protected) and
  # LLM-generated approved-candidate copy — and the two can't be told apart
  # retroactively by column. The candidate pipeline is new, so any such legacy
  # rows are few; they stamp themselves the next time they're generated. Leaving
  # them unstamped errs on the side of never clobbering a hand-written row.
  def up
    execute(<<~SQL.squish)
      UPDATE ai_models
      SET description_generated_at = created_at
      WHERE source = 'openrouter'
        AND description_generated_at IS NULL
        AND strengths IS NOT NULL AND strengths <> ''
    SQL
  end

  def down
    # One-way data backfill; nothing meaningful to reverse.
  end
end
