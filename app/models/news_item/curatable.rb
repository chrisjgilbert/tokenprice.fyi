module NewsItem::Curatable
  # Extract every ModelCandidate this item announces (a facade over the
  # operation object) — an array, empty when it announces no identifiable new
  # model. A single item can name several models (a digest can bundle more
  # than one launch), so this is never just zero-or-one.
  def extract_model_candidates
    NewsItem::ModelExtraction.new(self).run
  end
end
