class Provider < ApplicationRecord
  has_many :ai_models, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :set_slug, on: :create

  # Pretty URLs: /providers/anthropic
  def to_param = slug

  private

  def set_slug
    self.slug ||= name&.parameterize
  end
end
