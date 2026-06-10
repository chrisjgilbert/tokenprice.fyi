module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_admin

    private

    def require_admin
      redirect_to admin_login_path, alert: "Please sign in." unless session[:admin]
    end
  end
end
