require 'rails_helper'

# NOTE: This controller is deprecated. Authentication is now handled by Devise.
# See spec/controllers/users/sessions_controller_spec.rb for current tests.
# This file is kept for reference but tests are moved to the new location.

RSpec.describe SessionsController, type: :controller do
  # This controller may no longer exist or may be deprecated
  # All authentication tests should be in Users::SessionsController spec
  skip "SessionsController is deprecated. Use Users::SessionsController tests instead."
end
