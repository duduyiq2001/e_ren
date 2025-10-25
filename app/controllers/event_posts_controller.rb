class EventPostsController < ApplicationController
  def index
    @event_posts = EventPost.includes(:event_category, :organizer, :attendees).order(event_time: :asc)
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
  end

  def post
  end
end
