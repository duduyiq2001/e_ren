class EventPostsController < ApplicationController
  before_action :require_login

  def index
    @event_posts = EventPost.includes(:event_category, :organizer, :attendees).order(event_time: :asc)

    # Load user's registrations for these events
    if current_user
      event_ids = @event_posts.map(&:id)
      @user_registrations = current_user.event_registrations
                                        .where(event_post_id: event_ids)
                                        .index_by(&:event_post_id)
    end
  end

  def show
    @event_post = EventPost.find(params[:id])
    @registration = current_user.event_registrations.find_by(event_post: @event_post) if current_user
  end

  def find
  end

  def search
    @event_posts = EventPost.includes(:event_category, :organizer, :attendees)

    # Apply filters (they're chainable!)
    @event_posts = @event_posts.search_by_name(params[:q]) if params[:q].present?
    @event_posts = @event_posts.by_category(params[:category_id]) if params[:category_id].present?

    # Time filters
    if params[:time_filter] == 'today'
      @event_posts = @event_posts.today
    elsif params[:time_filter] == 'this_week'
      @event_posts = @event_posts.this_week
    elsif params[:time_filter] == 'upcoming'
      @event_posts = @event_posts.upcoming
    elsif params[:start_date].present? && params[:end_date].present?
      @event_posts = @event_posts.between_dates(params[:start_date], params[:end_date])
    else
      @event_posts = @event_posts.upcoming # Default to upcoming events
    end

    # Location filter
    if params[:latitude].present? && params[:longitude].present?
      radius = params[:radius].presence || 10
      @event_posts = @event_posts.near_location(params[:latitude], params[:longitude], radius)
    end

    @event_posts = @event_posts.order(event_time: :asc)
    @event_categories = EventCategory.all

    # Load user's registrations for these events (to show register/unregister buttons)
    if current_user
      event_ids = @event_posts.map(&:id)
      @user_registrations = current_user.event_registrations
                                        .where(event_post_id: event_ids)
                                        .index_by(&:event_post_id)
    end
  end

  def new
    @event_post = EventPost.new
    @event_categories = EventCategory.all
  end

  def create
    @event_post = current_user.organized_events.build(event_post_params)

    if @event_post.save
      redirect_to @event_post, notice: "Event created successfully!"
    else
      @event_categories = EventCategory.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @event_post = EventPost.find(params[:id])

    # Only allow organizer to edit
    unless current_user == @event_post.organizer
      redirect_to @event_post, alert: "You are not authorized to edit this event."
      return
    end

    @event_categories = EventCategory.all
  end

  def update
    @event_post = EventPost.find(params[:id])

    # Only allow organizer to update
    unless current_user == @event_post.organizer
      redirect_to @event_post, alert: "You are not authorized to update this event."
      return
    end

    if @event_post.update(event_post_params)
      redirect_to @event_post, notice: "Event updated successfully!"
    else
      @event_categories = EventCategory.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event_post = EventPost.find(params[:id])

    # Only allow organizer to delete
    unless current_user == @event_post.organizer
      redirect_to event_posts_index_path, alert: "You are not authorized to delete this event."
      return
    end

    @event_post.destroy
    redirect_to event_posts_index_path, notice: "Event deleted successfully."
  end

  def registrations
    @event_post = EventPost.find(params[:id])

    # Only allow organizer to view registrations
    unless current_user == @event_post.organizer
      redirect_to @event_post, alert: "You are not authorized to view registrations for this event."
      return
    end

    @registrations = @event_post.event_registrations
                                .includes(:user)
                                .order(registered_at: :asc)

    @confirmed_registrations = @registrations.where(status: :confirmed)
    @waitlisted_registrations = @registrations.where(status: :waitlisted)
  end

  private

  def event_post_params
    params.require(:event_post).permit(
      :name,
      :description,
      :event_category_id,
      :event_time,
      :capacity,
      :location_name,
      :google_maps_url
    )
  end
end
