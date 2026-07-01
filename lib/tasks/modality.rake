namespace :modality do
  # The `modality_class` column is a denormalised cache of the derivation in
  # `ModalityClass`, kept in lockstep by a `before_save` callback that only fires
  # when a row's signature changes. So a change to the *rules* (e.g. adding the
  # image_generation class) leaves already-stored rows on their old label until
  # their signature next moves. This one-off resynces the column to the current
  # rules. Idempotent: a row already in sync is skipped, and only the cache
  # column is written (no `updated_at` churn, since nothing user-visible changes
  # — the surfaces derive the class live).
  desc "Re-derive the cached modality_class column from each model's signature (idempotent)"
  task reclassify: :environment do
    updated = 0

    AiModel.find_each do |model|
      derived = model.modality_class.to_s
      next if model.read_attribute(:modality_class) == derived

      model.update_column(:modality_class, derived)
      updated += 1
      puts "  ✓ #{model.slug}: → #{derived}"
    end

    puts "Done: #{updated} row(s) reclassified."
  end
end
