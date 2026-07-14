require "test_helper"

class AiModel::SiblingTest < ActiveSupport::TestCase
  test "to_prompt_line combines name, release month, and summary" do
    sibling = AiModel::Sibling.new(name: "Wonder 2", released_on: Date.new(2026, 6, 1),
                                   summary: "Frontier reasoning model.")
    assert_equal "Wonder 2 (released 2026-06): Frontier reasoning model.", sibling.to_prompt_line
  end

  test "to_prompt_line omits the release when there is no date" do
    sibling = AiModel::Sibling.new(name: "Wonder 2", released_on: nil, summary: "A model.")
    assert_equal "Wonder 2: A model.", sibling.to_prompt_line
  end

  test "to_prompt_line omits the summary when blank" do
    sibling = AiModel::Sibling.new(name: "Wonder 2", released_on: Date.new(2026, 6, 1), summary: nil)
    assert_equal "Wonder 2 (released 2026-06)", sibling.to_prompt_line
  end
end
