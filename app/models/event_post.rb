class EventPost < ApplicationRecord
  # Associations
  belongs_to :event_category
  belongs_to :organizer, class_name: 'User', foreign_key: 'organizer_id'
  has_many :event_registrations, dependent: :destroy_async
  has_many :attendees, through: :event_registrations, source: :user

  # Geocoding
  geocoded_by :location_name
  after_validation :geocode, if: :should_geocode?

  # Scopes for filtering
  scope :search_by_name, ->(query) { where("name ILIKE ?", "%#{query}%") if query.present? }
  scope :by_category, ->(category_id) { where(event_category_id: category_id) if category_id.present? }
  scope :upcoming, -> { where("event_time >= ?", Time.current).order(event_time: :asc) }
  scope :today, -> { where(event_time: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :this_week, -> { where(event_time: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :between_dates, ->(start_date, end_date) {
    if start_date.present? && end_date.present?
      where(event_time: start_date.to_date.beginning_of_day..end_date.to_date.end_of_day)
    end
  }
  scope :near_location, ->(latitude, longitude, radius_miles = 10) {
    near([latitude, longitude], radius_miles) if latitude.present? && longitude.present?
  }

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
