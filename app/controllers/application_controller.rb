class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Devise provides current_user and user_signed_in? automatically
  # No need for custom authentication helpers

  private

  # Custom redirect paths after sign in/out
  def after_sign_in_path_for(resource)
    # First-time login: redirect to about page
    # sign_in_count is 1 after first successful login
    if resource.sign_in_count == 1
      about_path
    else
      root_path
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end
end
