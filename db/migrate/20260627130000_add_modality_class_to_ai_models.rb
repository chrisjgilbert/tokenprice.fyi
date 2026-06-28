class AddModalityClassToAiModels < ActiveRecord::Migration[8.1]
  def up
    # The single filterable class derived from the modality signature. Stored as a
    # column (not derived on read) so the `listed` scope can filter on it in SQL —
    # a price-less directory row (image-gen, TTS, …) is admitted by class. NOT NULL
    # with a 'text' default so a row inserted outside the model callback (a future
    # bulk import, a schema-load deploy) is treated as text rather than dropped by
    # the scope, and the column stays index-usable (no COALESCE wrapper needed).
    add_column :ai_models, :modality_class, :string, null: false, default: "text"
    add_index :ai_models, :modality_class

    # Backfill the non-text rows from the derived value (the default already
    # covers the text majority in one statement).
    AiModel.reset_column_information
    AiModel.find_each do |model|
      derived = ModalityClass.for(input: model.input_modalities, output: model.output_modalities).to_s
      model.update_column(:modality_class, derived) unless derived == "text"
    end
  end

  def down
    remove_column :ai_models, :modality_class
  end
end
