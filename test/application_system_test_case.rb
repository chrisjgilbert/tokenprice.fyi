require "test_helper"
require "selenium/webdriver"

# Point Selenium at an explicit chromedriver when one is provided. On CI and a
# stock dev machine the env var is unset and Selenium Manager resolves a driver
# that matches the installed Chrome; in sandboxed environments where the two
# can't be auto-matched, CHROMEDRIVER_PATH pins a known-good binary.
if (driver_path = ENV["CHROMEDRIVER_PATH"]).present?
  Selenium::WebDriver::Chrome::Service.driver_path = driver_path
end

Capybara.register_driver :tokenprice_headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--disable-gpu")
  options.add_argument("--disable-dev-shm-usage")
  # Required under most container sandboxes; harmless on a CI runner.
  options.add_argument("--no-sandbox")
  options.add_argument("--window-size=1400,1400")
  # CHROME_BINARY lets an environment supply its own Chromium build; left unset,
  # Selenium finds the system browser.
  if (binary = ENV["CHROME_BINARY"]).present?
    options.binary = binary
  end

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :tokenprice_headless_chrome, screen_size: [ 1400, 1400 ]
end
