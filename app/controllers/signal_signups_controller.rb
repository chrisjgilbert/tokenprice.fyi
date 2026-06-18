# Capture-only demand probes. Stores the opt-in and swaps the card for its
# success state inside its Turbo Frame. No email is sent and no measurement is
# performed — the opt-in itself is the signal.
class SignalSignupsController < ApplicationController
  def create
    @signup   = SignalSignup.new(signup_params)
    @frame_id = params[:frame_id].to_s.presence || "probe"
    @variant  = params[:variant] == "measure" ? "measure" : "alert"

    if @signup.save
      render partial: "signal_signups/probe_success",
             locals: { frame_id: @frame_id, variant: @variant, email: @signup.email }
    else
      render partial: "signal_signups/probe",
             locals: { frame_id: @frame_id, variant: @variant, payload: params[:payload],
                       title: params[:title], body: params[:body],
                       error: "Enter a valid email so we can reach you." },
             status: :unprocessable_entity
    end
  end

  private

  def signup_params
    params.permit(:kind, :email, :payload)
  end
end
