class EventNotificationMailer < ApplicationMailer
  default from: 'noreply@example.com'

  def enrollment_confirmation(event_registration)
    @event_registration = event_registration
    @user = event_registration.user
    @event = event_registration.event_post
    @organizer = @event.organizer
    @is_waitlisted = event_registration.waitlisted?

    subject = if @is_waitlisted
                "Waitlist Confirmation - #{@event.name}"
              else
                "Event Enrollment Confirmation - #{@event.name}"
              end

    mail(to: @user.email, subject: subject)
  end

  def waitlist_confirmed(event_registration)
    @event_registration = event_registration
    @user = event_registration.user
    @event = event_registration.event_post
    @organizer = @event.organizer

    mail(
      to: @user.email,
      subject: "You're In! - #{@event.name}"
    )
  end
end