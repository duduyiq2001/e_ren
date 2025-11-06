class EventRegistrationsController < ApplicationController
  before_action :require_login

  def create
    @event_post = EventPost.find(params[:event_post_id])
    @registration = current_user.event_registrations.build(event_post: @event_post)

    if @registration.save
      if @registration.waitlisted?
        redirect_to @event_post, notice: "Event is full. You've been added to the waitlist."
      else
        redirect_to @event_post, notice: "Successfully registered for the event!"
      end
    else
      redirect_to @event_post, alert: @registration.errors.full_messages.join(", ")
    end
  end

  def update
    @event_post = EventPost.find(params[:event_post_id])
    @registration = @event_post.event_registrations.find(params[:id])

    unless current_user == @event_post.organizer
      redirect_to @event_post, alert: "Not authorized"
      return
    end

    if @registration.update(status: params[:status])
      redirect_to @event_post, notice: "Registration status updated."
    else
      redirect_to @event_post, alert: @registration.errors.full_messages.join(", ")
    end
  end 

  def destroy
    @registration = current_user.event_registrations.find(params[:id])
    @event_post = @registration.event_post

    if @registration.destroy
       
      redirect_to @event_post, notice: "Successfully unregistered from the event."
    else
      redirect_to @event_post, alert: "Unable to unregister from the event."
    end
  end

  def approve_registration
    @event_post = EventPost.find(params[:event_post_id])
    @registration = @event_post.event_registrations.find(params[:id])

    # Only organizer can approve registration
    unless current_user == @event_post.organizer
      redirect_to @event_post, alert: "You are not authorized to approve registration."
      return
    end

    # Can only approve before event has ended
    unless @event_post.event_time > Time.current
      redirect_to registrations_event_post_path(@event_post), alert: "Cannot approve registration after the event ends."
      return
    end

    if @registration.update(status: :confirmed)
      redirect_to registrations_event_post_path(@event_post), notice: "Registration approved for #{@registration.user.name}"
    else
      redirect_to registrations_event_post_path(@event_post), alert: "Unable to approve registration."
    end
  end

  def confirm_attendance
    @event_post = EventPost.find(params[:event_post_id])
    @registration = @event_post.event_registrations.find(params[:id])

    # Only organizer can confirm attendance
    unless current_user == @event_post.organizer
      redirect_to @event_post, alert: "You are not authorized to confirm attendance."
      return
    end

    # Can only confirm attendance after event has ended
    unless @event_post.event_time < Time.current
      redirect_to registrations_event_post_path(@event_post), alert: "Cannot confirm attendance before the event ends."
      return
    end

    if @registration.update(attendance_confirmed: true)
      redirect_to registrations_event_post_path(@event_post), notice: "Attendance confirmed! #{@registration.user.name} earned 10 E-points."
    else
      redirect_to registrations_event_post_path(@event_post), alert: "Unable to confirm attendance."
    end
  end
end
