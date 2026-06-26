module NewsItem::Classifiable
  def classify
    NewsItem::Classification.new(self).run
  end
end
