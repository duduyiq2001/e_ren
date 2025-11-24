module ControllerHelpers
  def login_user(user)
    raise ArgumentError, "user cannot be nil" if user.nil?
    sign_in user
    user
  end

  def logout_user
    sign_out :user
  end
end
