class EventRegistration < ApplicationRecord
  belongs_to :user
  belongs_to :event_post, counter_cache: :registrations_count

  enum :status, { pending: 0, confirmed: 1, cancelled: 2, waitlisted: 3 }, default: :confirmed

  validates :user_id, uniqueness: { scope: :event_post_id, message: "has already registered for this event" }
  validate :event_not_full, on: :create

  after_create :send_enrollment_notification
  after_update :send_waitlist_to_confirmed_notification, if: -> { saved_change_to_status? && confirmed? && status_before_last_save == 'waitlisted' }

  private

  def set_registered_at
    self.registered_at ||= Time.current
  end

  def event_not_full
    return unless event_post

    if event_post.full? && !waitlisted?
      errors.add(:base, "Event is full. You have been added to the waitlist.")
      self.status = :waitlisted
    end
  end

  def send_enrollment_notification
    EnrollmentNotificationJob.perform_later(id)
  end

  #def send_waitlist_to_confirmed_notification
    # when user who stay in waiting list change to 
    #EventNotificationService.send_waitlist_confirmation(self)
  #end
end