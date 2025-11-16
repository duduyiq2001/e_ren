module RequestHelpers
  def sign_in_as(user)
    # Use Devise's sign_in helper for request specs
    sign_in user
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
