class Notification < ApplicationRecord
  self.table_name = 'notifications'

  belongs_to :user
  belongs_to :event_registration

  enum notification_type: {
    enrollment_confirmation: 'enrollment_confirmation',
    event_reminder: 'event_reminder',
    event_cancelled: 'event_cancelled',
    waitlist_confirmed: 'waitlist_confirmed'
  }

  validates :notification_type, presence: true

  scope :sent, -> { where.not(sent_at: nil) }
  scope :unsent, -> { where(sent_at: nil) }

  def mark_as_sent!
    update!(sent_at: Time.current)
  end
end