class Provider < ApplicationRecord
  has_many :ai_models, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :accent, format: { with: /\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/,
                               message: "must be a hex colour like #4f46e5" }, allow_blank: true

  before_validation :set_slug, on: :create

  # Pretty URLs: /providers/anthropic
  def to_param = slug

  private

  def set_slug
    self.slug ||= name&.parameterize
  end
end
