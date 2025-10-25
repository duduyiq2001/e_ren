class EventRegistration < ApplicationRecord
  belongs_to :user
  belongs_to :event_post, counter_cache: :registrations_count

  enum :status, { pending: 0, confirmed: 1, cancelled: 2, waitlisted: 3 }, default: :confirmed

  validates :user_id, uniqueness: { scope: :event_post_id, message: "has already registered for this event" }
  validate :event_not_full, on: :create

  before_validation :set_registered_at, on: :create

  private

  def set_registered_at
    self.registered_at ||= Time.current
  end

  def event_not_full
    return unless event_post

    if event_post.full? && status != 'waitlisted'
      errors.add(:base, "Event is full. You have been added to the waitlist.")
      self.status = :waitlisted
    end
  end
end
