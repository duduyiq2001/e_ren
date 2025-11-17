module MailerHelpers
  # Clear all emails before each test
  def clear_emails
    ActionMailer::Base.deliveries.clear
  end

  # Get the last sent email
  def last_email
    ActionMailer::Base.deliveries.last
  end

  # Get all sent emails
  def all_emails
    ActionMailer::Base.deliveries
  end

  # Find emails sent to a specific address
  def emails_to(address)
    ActionMailer::Base.deliveries.select { |email| email.to.include?(address) }
  end

  # Find emails with a specific subject
  def emails_with_subject(subject_pattern)
    ActionMailer::Base.deliveries.select { |email| email.subject.match?(subject_pattern) }
  end

  # Extract confirmation token from confirmation email
  def confirmation_token_from_email(email)
    body = email.html_part ? email.html_part.body.to_s : email.body.to_s
    match = body.match(/confirmation_token=([^"&]+)/)
    match ? match[1] : nil
  end

  # Extract reset password token from password reset email
  def reset_password_token_from_email(email)
    body = email.html_part ? email.html_part.body.to_s : email.body.to_s
    match = body.match(/reset_password_token=([^"&]+)/)
    match ? match[1] : nil
  end

  # Mock email delivery (prevents actual sending)
  def mock_email_delivery
    allow(ActionMailer::Base).to receive(:deliver_mail).and_return(true)
  end

  # Verify that an email was sent
  def expect_email_to_be_sent(options = {})
    expect {
      yield
    }.to change { ActionMailer::Base.deliveries.count }.by(options[:count] || 1)

    if options[:to]
      email = ActionMailer::Base.deliveries.last
      expect(email.to).to include(options[:to])
    end

    if options[:subject]
      email = ActionMailer::Base.deliveries.last
      expect(email.subject).to match(options[:subject])
    end
  end

  # Verify that no email was sent
  def expect_no_email_to_be_sent
    expect {
      yield
    }.not_to change { ActionMailer::Base.deliveries.count }
  end

  # ============================================
  # Email Authentication Specific Helpers
  # ============================================

  # Register a user and return the confirmation email
  def register_user_and_get_confirmation_email(email: "test@wustl.edu", password: "password123", name: "Test User")
    post user_registration_path, params: {
      user: {
        email: email,
        password: password,
        password_confirmation: password,
        name: name
      }
    }
    last_email
  end

  # Get confirmation token from the last sent confirmation email
  def last_confirmation_token
    email = last_email
    return nil unless email
    confirmation_token_from_email(email)
  end

  # Get reset password token from the last sent password reset email
  def last_reset_password_token
    email = last_email
    return nil unless email
    reset_password_token_from_email(email)
  end

  # Confirm user email using token from the confirmation email
  def confirm_user_email_via_email(email_address)
    confirmation_email = emails_to(email_address).find { |e| e.subject.match?(/confirm/i) }
    return nil unless confirmation_email

    token = confirmation_token_from_email(confirmation_email)
    return nil unless token

    get user_confirmation_path(confirmation_token: token)
    token
  end

  # Complete registration flow: register -> get email -> confirm
  def complete_registration_flow(email: "test@wustl.edu", password: "password123", name: "Test User")
    # Register
    register_user_and_get_confirmation_email(email: email, password: password, name: name)
    
    # Get user
    user = User.find_by(email: email)
    
    # Confirm using token from email
    token = last_confirmation_token
    get user_confirmation_path(confirmation_token: token) if token
    
    user.reload
    user
  end

  # Request password reset and get the reset email
  def request_password_reset_and_get_email(email)
    post user_password_path, params: { user: { email: email } }
    last_email
  end

  # Complete password reset flow: request -> get email -> reset password
  def complete_password_reset_flow(user, new_password: "newpassword123")
    # Request reset
    request_password_reset_and_get_email(user.email)
    user.reload
    
    # Get token from email
    token = last_reset_password_token
    
    # Reset password
    if token
      patch user_password_path, params: {
        user: {
          reset_password_token: token,
          password: new_password,
          password_confirmation: new_password
        }
      }
    end
    
    user.reload
    token
  end
end

RSpec.configure do |config|
  config.include MailerHelpers

  # Clear emails before each test
  config.before(:each) do
    ActionMailer::Base.deliveries.clear
  end
end

