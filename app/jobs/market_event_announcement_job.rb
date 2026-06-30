# Posts a published MarketEvent to the social accounts off the web request, so a
# slow or flaky social API can't block the admin publish action. All the work
# lives in MarketEvent::Announcement; this is just the schedulable wrapper.
class MarketEventAnnouncementJob < ApplicationJob
  queue_as :default

  def perform(event)
    MarketEvent::Announcement.new(event).run
  end
end
