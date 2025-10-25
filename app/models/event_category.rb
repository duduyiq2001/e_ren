class EventCategory < ApplicationRecord
  has_many :event_posts, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, allow_blank: true, message: "must be a valid hex color (e.g., #FF5733)" }
end
