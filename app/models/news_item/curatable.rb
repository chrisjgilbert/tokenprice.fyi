module NewsItem::Curatable
  # Extract a ModelCandidate from this item (a facade over the operation object),
  # or nil when it doesn't announce an identifiable new model.
  def extract_model_candidate
    NewsItem::ModelExtraction.new(self).run
  end
end
