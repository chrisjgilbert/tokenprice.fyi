module MarketEvent::Announceable
  def announce
    MarketEvent::Announcement.new(self).run
  end
end
