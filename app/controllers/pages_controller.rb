class PagesController < ApplicationController
  def which_model
  end

  def how_pricing_works
    @frontier_example = AiModel.listed.where(tier: "frontier")
                              .select(&:current_input)
                              .min_by(&:current_input)
  end
end
