module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_admin

    # Admin sessions expire after this much inactivity, and after this long in
    # total regardless of activity — a stolen or forgotten session can't live
    # forever.
    IDLE_TIMEOUT     = 2.hours
    ABSOLUTE_TIMEOUT = 12.hours

    private

    def require_admin
      unless session[:admin]
        redirect_to admin_login_path, alert: "Please sign in." and return
      end

      if admin_session_expired?
        reset_session
        redirect_to admin_login_path, alert: "Your session expired. Please sign in again." and return
      end

      # Back-fill the absolute-cap anchor for sessions created before this was
      # introduced, so they too are capped from first contact.
      session[:admin_since]   ||= Time.current.to_i
      session[:admin_seen_at]   = Time.current.to_i
    end

    def admin_session_expired?
      now     = Time.current.to_i
      seen_at = session[:admin_seen_at].to_i
      since   = session[:admin_since].to_i

      (seen_at.positive? && now - seen_at > IDLE_TIMEOUT.to_i) ||
        (since.positive? && now - since > ABSOLUTE_TIMEOUT.to_i)
    end
  end
end
