module ControllerHelpers
  def login_user(user = nil)
    user ||= create(:user, :confirmed)
    sign_in user
    user
  end

  def logout_user
    sign_out :user
  end
end
