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
      @filtered_events = @attended_events.where('event_time > ?', Time.current)
                                        .where.not(organizer_id: @user.id)
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

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      log_in(@user)
      redirect_to root_path, notice: "Welcome to E-Ren! Your account has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def search
    query = params[:q]
    if query.present?
      @users = User.where("name ILIKE ?", "%#{query}%").limit(10)
    else
      @users = []
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :phone_number)
  end
end
