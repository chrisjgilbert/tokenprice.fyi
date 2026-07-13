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

  # Write the four editorial columns from a generated copy hash, keeping an
  # existing description when the generated one is blank — an upstream blurb we
  # already have beats an empty regeneration. Assigns in memory; the caller
  # saves (the facade above here, the import save in OpenRouter::ModelSync).
  def apply_editorial(copy)
    self.description = copy[:description] if copy[:description].present?
    self.strengths   = copy[:strengths]
    self.best_for    = copy[:best_for]
    self.limitations = copy[:limitations]
  end
end
