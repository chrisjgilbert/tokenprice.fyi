# A capture-only demand probe. V1 stores the opt-in; no email is ever sent and
# no measurement is performed — the opt-in itself is the data (the gate metric
# for whether to build the measure-&-optimize product).
class SignalSignup < ApplicationRecord
  # The two probes. "measure_interest" is the primary signal that the second
  # product is wanted; "price_alert" is the secondary retention signal.
  KINDS = %w[measure_interest price_alert].freeze

  # Loose, forgiving email shape — we validate intent, not deliverability.
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :email, presence: true, format: { with: EMAIL_FORMAT }

  before_validation { self.email = email.to_s.strip.downcase.presence }

  scope :measure_interest, -> { where(kind: "measure_interest") }
  scope :price_alerts,     -> { where(kind: "price_alert") }
end
