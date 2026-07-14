# Facade for generating a model's editorial write-up — a one-line description
# plus strengths / best-for / limitations — reached as ai_model.generate_description.
# Mirrors Insightful: delegates to the AiModel::Description operation and persists.
# The OpenRouter sync runs the same operation inline on an unpersisted row; this
# is the entry point for filling a *saved* record (e.g. a freshly curated model).
module AiModel::Describable
  # How many provider-siblings to feed the generator for positioning. Enough to
  # cover a model's generation and its nearest successors without ballooning the
  # prompt for a big catalogue (see sibling_lineup for how the cohort is picked).
  LINEUP_LIMIT = 12

  def generate_description(client: nil)
    copy = AiModel::Description.new(client: client).generate(
      name:           name,
      provider:       provider.name,
      context_window: context_window,
      source_text:    description.presence,
      lineup:         sibling_lineup
    )
    apply_editorial(copy)
    save!
  end

  # Regenerate the editorial copy of an already-written-up row whose description
  # has gone stale (see AiModel.description_stale). Distinct from
  # generate_description in two ways that matter only when replacing good copy:
  #
  #   - No source_text. A refresh regenerates from Claude's current knowledge of
  #     the model rather than feeding the stale description back in, so it isn't
  #     anchored into paraphrasing the very text it's meant to replace.
  #   - Degradation guard. A regeneration that comes back thin (any blank facet)
  #     is not applied — the existing write-up is kept and the row's timestamp is
  #     bumped so it waits a full window before we try again, rather than blanking
  #     a good facet or re-attempting an un-describable model every run.
  #
  # The lineup is the point of a refresh: a launch flags a sibling as stale (see
  # AiModel.description_stale), and feeding the newer release in lets the rewrite
  # actually reposition against it ("superseded by X", "the tier below Y").
  def refresh_description(client: nil)
    copy = AiModel::Description.new(client: client).generate(
      name:           name,
      provider:       provider.name,
      context_window: context_window,
      lineup:         sibling_lineup
    )

    if copy.values.all?(&:present?)
      apply_editorial(copy)
    else
      self.description_generated_at = Time.current
    end
    save!
  end

  # The provider-siblings to position this model against, as compact Sibling
  # descriptors, presented newest first. Self is excluded once persisted; an
  # unsaved row (the OpenRouter import) isn't in the table yet, so nothing to
  # exclude. When a provider has more than LINEUP_LIMIT models the cohort is
  # chosen by release-proximity (see most_relevant), so an older model is
  # positioned against its own generation and nearest successors rather than a
  # dozen newer, possibly different-tier releases.
  def sibling_lineup(limit: LINEUP_LIMIT)
    scope = provider.ai_models.listed
    scope = scope.where.not(id: id) if persisted?

    most_relevant(scope.to_a, limit)
      .sort_by { |sib| sib.released_on || Date.new(0) }.reverse
      .map do |sib|
        AiModel::Sibling.new(
          name:        sib.name,
          released_on: sib.released_on,
          summary:     sib.description.to_s.squish.truncate(160).presence
        )
      end
  end

  # Write the four editorial columns from a generated copy hash, keeping an
  # existing description when the generated one is blank — an upstream blurb we
  # already have beats an empty regeneration. Stamps description_generated_at so
  # the freshness clock (staleness, refresh ordering) starts from this write.
  # Assigns in memory; the caller saves (the facades here, the import save in
  # OpenRouter::ModelSync).
  def apply_editorial(copy)
    self.description = copy[:description] if copy[:description].present?
    self.strengths   = copy[:strengths]
    self.best_for    = copy[:best_for]
    self.limitations = copy[:limitations]
    self.description_generated_at = Time.current
  end

  private

  # Pick the `limit` siblings most useful for positioning this model: those
  # released closest to it in time — its own generation and nearest successors —
  # so a provider with more than `limit` models yields the target's cohort rather
  # than only the globally newest rows (which may be a different tier). Ties break
  # toward the newer sibling (the more likely successor). Undated siblings rank
  # last. With no release date to anchor on we can't measure proximity, so fall
  # back to the newest siblings.
  def most_relevant(siblings, limit)
    return siblings.sort_by { |s| s.released_on || Date.new(0) }.last(limit) if released_on.nil?

    dated, undated = siblings.partition(&:released_on)
    nearest = dated.sort_by do |sib|
      delta = (sib.released_on - released_on).to_i
      [ delta.abs, -delta ]
    end
    (nearest + undated).first(limit)
  end
end
