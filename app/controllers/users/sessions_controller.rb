class Users::SessionsController < Devise::SessionsController
  def create
    # Only check for user existence if email is provided
    if params[:user] && params[:user][:email].present?
      user = User.find_by(email: params[:user][:email])
      
      if user.nil?
        flash[:alert] = "User not found"
        redirect_to new_user_session_path
        return
      end
    end
    # Let Devise handle authentication (including missing email case)
    super
  end
end

