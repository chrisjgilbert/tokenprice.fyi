class AddModalityClassToAiModels < ActiveRecord::Migration[8.1]
  def up
    # The single filterable class derived from the modality signature. Stored as a
    # column (not derived on read) so the `listed` scope can filter on it in SQL —
    # a price-less non-text directory row (image-gen, TTS, …) is admitted by class.
    add_column :ai_models, :modality_class, :string
    add_index :ai_models, :modality_class

    # Backfill every existing row from the derived value so the column is populated
    # on deploy. Uses the same value object that the model's callback will use.
    AiModel.reset_column_information
    AiModel.find_each do |model|
      model.update_column(
        :modality_class,
        ModalityClass.for(input: model.input_modalities, output: model.output_modalities).to_s
      )
    end
  end

  def down
    remove_column :ai_models, :modality_class
  end
end
