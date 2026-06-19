module Admin
  class SessionsController < BaseController
    # The login screen itself must be reachable without a session.
    skip_before_action :require_admin, only: %i[new create]

    # Throttle password guessing (Rails 8, backed by Solid Cache).
    rate_limit to: 10, within: 3.minutes, only: :create,
               with: -> { redirect_to admin_login_path, alert: "Too many attempts. Try again shortly." }

    def new
      redirect_to admin_root_path if session[:admin]
    end

    def create
      if correct_password?(params[:password].to_s)
        reset_session            # rotate the session id on privilege change
        session[:admin] = true
        # Stamp the session so BaseController can enforce idle + absolute expiry.
        session[:admin_since] = session[:admin_seen_at] = Time.current.to_i
        redirect_to admin_root_path, notice: "Signed in."
      else
        flash.now[:alert] = "Incorrect password."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      reset_session
      redirect_to admin_login_path, notice: "Signed out."
    end

    private

    # The bcrypt digest lives in the app's encrypted credentials
    # (Rails.application.credentials.admin_password_digest). Set it with:
    #   bin/rails runner 'puts BCrypt::Password.create("your-password")'
    #   bin/rails credentials:edit   # add: admin_password_digest: "<digest>"
    def correct_password?(password)
      digest = Rails.application.credentials.admin_password_digest
      return false if digest.blank? || password.blank?

      BCrypt::Password.new(digest).is_password?(password)
    rescue BCrypt::Errors::InvalidHash
      false
    end
  end
end
