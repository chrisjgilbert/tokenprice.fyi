class ComparisonsController < ApplicationController
  # /compare?a=claude-opus-4-8&b=gpt-5-5  → side-by-side of two models.
  #
  # The comparison is scoped to one pricing category: the left model sets it, and
  # both pickers and the right model are drawn from that category. Comparing an
  # image model against a language model produces a table of dashes (their units
  # don't line up), so a cross-category `b` is ignored rather than rendered.
  def show
    all = AiModel.listed.includes(:provider, :price_points).by_release.to_a

    @left = find_model(all, params[:a]) || default_left(all)
    @category = ModelCategory.claiming(@left.modality_class)

    # Picker options and the right model come from the left's category only.
    @all_models = all.select { |m| @category.member?(m.modality_class) }
    @right = find_model(@all_models, params[:b]) || default_right(@all_models, @left)
  end

  private

  def find_model(models, slug)
    return nil if slug.blank?

    models.find { |m| m.slug == slug }
  end

  def default_left(all)
    all.find { |m| m.slug == "claude-opus-4-8" } || all.first
  end

  def default_right(models, left)
    models.find { |m| m.slug == "gpt-5-5" } ||
      models.find { |m| m != left }
  end
end
