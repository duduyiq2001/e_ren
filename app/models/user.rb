class User < ApplicationRecord
  # Authentication
  has_secure_password

  # Associations
  has_many :organized_events, class_name: 'EventPost', foreign_key: 'organizer_id', dependent: :destroy
  has_many :event_registrations, dependent: :destroy
  has_many :attended_events, through: :event_registrations, source: :event_post

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 100 }
  validates :password, presence: true, length: { minimum: 6 }, on: :create
  validates :phone_number, format: { with: /\A\+?[0-9\s\-\(\)]+\z/, allow_blank: true, message: "must be a valid phone number" }
  validates :e_score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :by_e_score, -> { order(e_score: :desc) }
  scope :top_n, ->(n = 10) { by_e_score.limit(n) }

  # Methods
  def attending?(event_post)
    attended_events.include?(event_post)
  end

  def organizing?(event_post)
    organized_events.include?(event_post)
  end
end
