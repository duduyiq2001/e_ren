class Users::SessionsController < Devise::SessionsController
  def create
    # Check if user exists first
    user = User.find_by(email: params[:user][:email]) if params[:user] && params[:user][:email].present?
    
    if user.nil?
      flash[:alert] = "User not found"
      redirect_to new_user_session_path
      return
    end

    # If user exists, use Devise's default authentication
    super
  end
end

