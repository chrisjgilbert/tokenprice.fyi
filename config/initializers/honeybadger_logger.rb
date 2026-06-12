# Forward warn/error/fatal log lines to Honeybadger Insights as structured events.
# Only active in production so local dev isn't noisy.
Rails.application.config.after_initialize do
  next unless Rails.env.production? && Honeybadger.config.insights_enabled?

  hb_device = Object.new.tap do |dev|
    dev.define_singleton_method(:write) do |message|
      msg = message.to_s.strip
      Honeybadger.event("log", message: msg) unless msg.empty?
    end
    dev.define_singleton_method(:close) {}
    dev.define_singleton_method(:flush) {}
  end

  hb_logger = ActiveSupport::Logger.new(hb_device)
  hb_logger.level = Logger::WARN

  Rails.logger.broadcast_to(hb_logger)
end
