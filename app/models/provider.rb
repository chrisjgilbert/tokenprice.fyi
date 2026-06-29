class Provider < ApplicationRecord
  has_many :ai_models, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :accent, format: { with: /\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/,
                               message: "must be a hex colour like #4f46e5" }, allow_blank: true
  validates :country_code, format: { with: /\A[A-Z]{2}\z/,
                                      message: "must be a 2-letter ISO code like US" }, allow_blank: true
  # A short editorial blurb for the provider page (a sentence or two); the cap is
  # a sanity guard on the admin free-text field, not a hard editorial limit.
  validates :description, length: { maximum: 1000 }, allow_blank: true

  before_validation :set_slug, on: :create
  before_validation :normalize_country_code

  # Pretty URLs: /providers/anthropic
  def to_param = slug

  # 🇺🇸 — the flag emoji for the headquarters country, built from the ISO
  # alpha-2 code via Unicode regional-indicator symbols. Guards on the format
  # so an out-of-band bad value can't map to arbitrary codepoints.
  def flag_emoji
    code = country_code.to_s.upcase
    return unless code.match?(/\A[A-Z]{2}\z/)

    code.each_char.map { |c| (0x1F1E6 + (c.ord - "A".ord)).chr(Encoding::UTF_8) }.join
  end

  private

  def set_slug
    self.slug ||= name&.parameterize
  end

  def normalize_country_code
    self.country_code = country_code.presence&.strip&.upcase
  end
end
