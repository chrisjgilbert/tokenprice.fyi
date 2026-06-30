module MarketEvent::Announceable
  def announce
    MarketEventAnnouncementJob.perform_later(self)
  end
end
