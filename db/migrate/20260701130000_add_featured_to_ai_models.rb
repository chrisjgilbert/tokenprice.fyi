class AddFeaturedToAiModels < ActiveRecord::Migration[8.1]
  def change
    # An editorial override for the hero's same-day launch tie-break: no
    # automatic signal (tier, price, provider) reliably ranks "this launch is
    # the story" against an unrelated same-day release, so a curator sets it
    # by hand. Superseded by the mini-timeline design in the next migration,
    # which dropped the tie-break (and this column) in favor of just showing
    # several events at once.
    add_column :ai_models, :featured, :boolean, default: false, null: false
  end
end
