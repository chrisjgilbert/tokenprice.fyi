class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Conditional GET for public reference pages, keyed on the catalog's freshness
  # (the latest price-row write). Callers pass an `etag:` array carrying every
  # param the page varies by, so a filtered/sorted view never 304s off another
  # view's cache. Pass `last_modified:` to override (e.g. a single model's price
  # date on a show page). Returns true when a 304 was rendered, so the action can
  # `return` and skip the rest of its work.
  def catalog_fresh?(etag:, last_modified: PriceCatalog.last_modified)
    fresh_when(etag: etag, last_modified: last_modified, public: true)
    performed?
  end
end
