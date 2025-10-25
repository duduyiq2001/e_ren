class EventPost < ApplicationRecord
  # Associations
  belongs_to :event_category
  belongs_to :organizer, class_name: 'User', foreign_key: 'organizer_id'
  has_many :event_registrations, dependent: :async_destroy
  has_many :attendees, through: :event_registrations, source: :user

  # Geocoding
  geocoded_by :location_name
  after_validation :geocode, if: :should_geocode?

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :capacity, presence: true, numericality: { greater_than: 0 }
  validates :event_time, presence: true
  validates :google_maps_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }

  # Custom validations
  validate :event_time_cannot_be_in_the_past, on: :create

  # Methods
  def spots_remaining
    capacity - (registrations_count || 0)
  end

  def full?
    spots_remaining <= 0
  end

  def parse_google_maps_url
    return unless google_maps_url.present?

    # Extract coordinates from Google Maps URL
    # Handles formats like:
    # - https://maps.google.com/?q=37.7749,-122.4194
    # - https://www.google.com/maps/place/.../@37.7749,-122.4194,17z
    # - https://www.google.com/maps/@37.7749,-122.4194,15z

    url = google_maps_url

    # Pattern 1: ?q=lat,lng
    if match = url.match(/[?&]q=(-?\d+\.?\d*),(-?\d+\.?\d*)/)
      self.latitude = match[1].to_f
      self.longitude = match[2].to_f
      return true
    end

    # Pattern 2: /@lat,lng
    if match = url.match(/@(-?\d+\.?\d*),(-?\d+\.?\d*)/)
      self.latitude = match[1].to_f
      self.longitude = match[2].to_f
      return true
    end

    # Pattern 3: place_id in URL
    if match = url.match(/place_id=([^&]+)/)
      self.google_place_id = match[1]
      return true
    end

    false
  end

  private

  def should_geocode?
    location_name.present? && (location_name_changed? || latitude.blank?)
  end

  def event_time_cannot_be_in_the_past
    if event_time.present? && event_time < Time.current
      errors.add(:event_time, "can't be in the past")
    end
  end
end
