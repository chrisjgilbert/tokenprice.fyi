class AddModalitiesToAiModels < ActiveRecord::Migration[8.1]
  def change
    # The modality signature: the small, sorted string sets a model accepts and
    # produces (e.g. ["image", "text"] in, ["text"] out). Derived from these, the
    # ModalityClass value object yields the single filterable class. Default [] so
    # existing text rows degrade to the `text` class without a backfill.
    add_column :ai_models, :input_modalities, :json, default: [], null: false
    add_column :ai_models, :output_modalities, :json, default: [], null: false
  end
end
