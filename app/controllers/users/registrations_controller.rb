class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :phone_number])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :phone_number])
  end

  # Redirect after sign up (before email confirmation)
  # When confirmable is enabled, Devise doesn't sign in the user automatically
  def after_sign_up_path_for(resource)
    # Redirect to custom confirmation pending page with user's email
    confirmations_pending_path(email: resource.email)
  end

  # Redirect for inactive users (unconfirmed)
  def after_inactive_sign_up_path_for(resource)
    # Redirect to custom confirmation pending page with user's email
    confirmations_pending_path(email: resource.email)
  end

  # Redirect after email confirmation
  def after_confirmation_path_for(resource_name, resource)
    new_user_session_path
  end
end

