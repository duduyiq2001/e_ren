class EnrollmentNotificationJob < ApplicationJob
  queue_as :default

  def perform(event_registration_id)
    event_registration = EventRegistration.find(event_registration_id)
    send_enrollment_notification(event_registration)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "EnrollmentNotificationJob failed: #{e.message}"
  end

  private

  def send_enrollment_notification(event_registration)
    EventNotificationMailer.enrollment_confirmation(event_registration).deliver_later
  end
end