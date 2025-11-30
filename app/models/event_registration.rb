class EventRegistration < ApplicationRecord
  belongs_to :user
  belongs_to :event_post

  enum :status, { pending: 0, confirmed: 1, waitlisted: 3 }, default: :pending

  validates :user_id, uniqueness: { scope: :event_post_id, message: "has already registered for this event" }
  validate :event_not_past, on: :create
  validate :event_not_full, on: :create

  before_validation :set_registered_at, on: :create
  before_validation :auto_confirm_if_not_required, on: :create

  # Counter cache management - only count confirmed registrations
  after_create :increment_confirmed_count, if: :confirmed?
  after_destroy :decrement_confirmed_count, if: :confirmed?
  before_destroy :promote_potential_candidate
  after_update :update_confirmed_count, if: :saved_change_to_status?

  after_create :send_enrollment_notification, unless: :pending?
  after_update :send_pending_to_confirmed_notification, if: -> { saved_change_to_status? && confirmed? && status_before_last_save == 'pending' }
  after_update :send_waitlist_to_confirmed_notification, if: -> { saved_change_to_status? && confirmed? && status_before_last_save == 'waitlisted' }
  after_update :award_e_score, if: -> { saved_change_to_attendance_confirmed? && attendance_confirmed? }

  # Public method - can be called by controllers or other models
  def promote_from_waitlist!
    # Promote a waitlisted registration to confirmed
    update!(status: :confirmed)
    # This will trigger:
    # - after_update :update_confirmed_count (increments counter)
    # - after_update :send_waitlist_to_confirmed_notification
  end

  private

  def promote_potential_candidate
    # When a confirmed registration is cancelled, promote the next waitlisted person
    # Only if event doesn't require manual approval
    return unless confirmed? # Only promote if a confirmed spot opened up
    return if event_post.requires_approval? # Don't auto-promote if manual approval required

    # Find the oldest waitlisted registration (oldest person on waitlist gets the spot)
    candidate = event_post.waitlisted_registrations.order(:created_at).first

    if candidate
      candidate.promote_from_waitlist!
    end
  end

  def set_registered_at
    self.registered_at ||= Time.current
  end

  def auto_confirm_if_not_required
    # Auto-confirm if event doesn't require approval
    if event_post && !event_post.requires_approval? && pending?
      self.status = :confirmed
    end
  end

  def event_not_past
    return unless event_post
    if event_post.event_time < Time.current
      errors.add(:base, "Cannot register for an event that has already started")
    end
  end

  def event_not_full
    return unless event_post
    return if !confirmed? && !event_post.requires_approval? # Only check capacity for confirmed registrations

    if event_post.full?
      self.status = :waitlisted
    end
  end

  # Counter cache management methods
  def increment_confirmed_count
    event_post.increment!(:registrations_count)
  end

  def decrement_confirmed_count
    event_post.decrement!(:registrations_count)
  end

  def update_confirmed_count
    # When status changes TO confirmed, increment
    if confirmed? && status_before_last_save != 'confirmed'
      event_post.increment!(:registrations_count)
    # When status changes FROM confirmed, decrement
    elsif !confirmed? && status_before_last_save == 'confirmed'
      event_post.decrement!(:registrations_count)
    end
  end

  def send_enrollment_notification
    EnrollmentNotificationJob.perform_later(id)
  end

  def send_pending_to_confirmed_notification
    EventNotificationMailer.enrollment_confirmation(self).deliver_later
  end

  def send_waitlist_to_confirmed_notification
    EventNotificationMailer.waitlist_confirmed(self).deliver_later
  end

  def award_e_score
    # Award 10 points for attending an event
    user.increment!(:e_score, 10)
  end
end
