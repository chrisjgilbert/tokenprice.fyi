# Facade for generating a model's editorial write-up — a one-line description
# plus strengths / best-for / limitations — reached as ai_model.generate_description.
# Mirrors Insightful: delegates to the AiModel::Description operation and persists.
# The OpenRouter sync runs the same operation inline on an unpersisted row; this
# is the entry point for filling a *saved* record (e.g. a freshly curated model).
module AiModel::Describable
  def generate_description(client: nil)
    copy = AiModel::Description.new(client: client).generate(
      name:           name,
      provider:       provider.name,
      context_window: context_window,
      source_text:    description.presence
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
  def refresh_description(client: nil)
    copy = AiModel::Description.new(client: client).generate(
      name:           name,
      provider:       provider.name,
      context_window: context_window
    )

    if copy.values.all?(&:present?)
      apply_editorial(copy)
    else
      self.description_generated_at = Time.current
    end
    save!
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
end
