class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])

    # Get all events (organized and attended)
    @organized_events = @user.organized_events.includes(:event_category).order(event_time: :asc)
    @attended_events = @user.attended_events.includes(:event_category, :organizer).order(event_time: :asc)

    # Filter events by type (upcoming, registered, organized, completed)
    @event_filter = params[:filter] || 'registered'

    case @event_filter
    when 'registered'
      # Show upcoming registered events (not organized by user)
      # Split into confirmed and pending registrations
      all_upcoming_registrations = @user.event_registrations
                                        .includes(event_post: [:event_category, :organizer])
                                        .joins(:event_post)
                                        .where('event_posts.event_time > ?', Time.current)
                                        .order('event_posts.event_time ASC')

      @confirmed_registrations = all_upcoming_registrations.confirmed.map(&:event_post)
      @pending_registrations = all_upcoming_registrations.pending.map(&:event_post)
      @filtered_events = @confirmed_registrations + @pending_registrations
    when 'organized'
      # Show upcoming organized events
      @filtered_events = @organized_events.where('event_time > ?', Time.current)
    when 'completed'
      # Show past organized events
      @filtered_events = @organized_events.where('event_time <= ?', Time.current)
    else
      @filtered_events = @attended_events.where('event_time > ?', Time.current)
    end

    # Calculate stats
    @stats = {
      total_attended: @user.event_registrations.where(status: :confirmed).count,
      total_organized: @user.organized_events.count,
      e_points: @user.e_score
    }
  end

  def search
    query = params[:q]
    if query.present?
      @users = User.where("name ILIKE ?", "%#{query}%").limit(10)
    else
      @users = []
    end
  end

end
