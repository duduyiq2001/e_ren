class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])
    @organized_events = @user.organized_events.includes(:event_category).order(event_time: :asc)
    @attended_events = @user.attended_events.includes(:event_category, :organizer).order(event_time: :asc)
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
