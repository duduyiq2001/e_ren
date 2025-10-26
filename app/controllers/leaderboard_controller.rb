class LeaderboardController < ApplicationController
  before_action :require_login

  def index
    # Get time period from params (defaults to 'weekly')
    # Note: For now, we'll show all-time rankings since we don't track weekly E-score changes yet
    # TODO: Add weekly E-score tracking when implementing E-score calculation logic

    @time_period = params[:time_period] || 'weekly'
    @top_users = User.top_n(10).select(:id, :name, :email, :e_score)

    # Add rank to each user
    @leaderboard = @top_users.map.with_index(1) do |user, index|
      {
        rank: index,
        user: user,
        is_current_user: (user.id == current_user.id)
      }
    end
  end
end
