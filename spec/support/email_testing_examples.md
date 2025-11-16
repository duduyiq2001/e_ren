# Email Testing Guide

## Overview

The test environment uses ActionMailer's `:test` delivery method, which **mocks** the email system. Emails are stored in `ActionMailer::Base.deliveries` array but are **never actually sent**.

## Configuration

The test environment is configured in `config/environments/test.rb`:

```ruby
config.action_mailer.delivery_method = :test
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
```

## Helper Methods

The `MailerHelpers` module provides convenient methods for testing emails:

### Basic Usage

```ruby
# Clear all emails before a test
clear_emails

# Get the last sent email
email = last_email

# Get all sent emails
all_emails

# Find emails sent to a specific address
emails_to("user@example.com")

# Find emails with a specific subject
emails_with_subject(/confirm/i)
```

### Extract Tokens from Emails

```ruby
# Extract confirmation token from email
token = confirmation_token_from_email(email)

# Extract reset password token from email
token = reset_password_token_from_email(email)
```

### Expect Email to be Sent

```ruby
# Expect exactly one email to be sent
expect_email_to_be_sent do
  post user_registration_path, params: valid_params
end

# Expect email to be sent to specific address
expect_email_to_be_sent(to: "user@example.com") do
  post user_registration_path, params: valid_params
end

# Expect email with specific subject
expect_email_to_be_sent(subject: /confirm/i) do
  post user_registration_path, params: valid_params
end

# Expect multiple emails
expect_email_to_be_sent(count: 2) do
  # action that sends 2 emails
end
```

### Expect No Email to be Sent

```ruby
expect_no_email_to_be_sent do
  # action that should not send emails
end
```

## Custom Matchers

Custom RSpec matchers are available for more expressive tests:

```ruby
# Check if email was sent
expect {
  post user_registration_path, params: valid_params
}.to have_sent_email

# Check if specific number of emails were sent
expect {
  # action
}.to have_sent_email(2)

# Check if email was sent to specific address
expect {
  post user_registration_path, params: valid_params
}.to have_sent_email_to("user@example.com")

# Check if email was sent with specific subject
expect {
  post user_registration_path, params: valid_params
}.to have_sent_email_with_subject(/confirm/i)
```

## Example Test

```ruby
RSpec.describe "User Registration", type: :request do
  it "sends confirmation email" do
    expect {
      post user_registration_path, params: {
        user: {
          email: "test@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    }.to change { ActionMailer::Base.deliveries.count }.by(1)

    email = last_email
    expect(email.to).to include("test@example.com")
    expect(email.subject).to match(/confirm/i)
    
    # Extract confirmation token
    token = confirmation_token_from_email(email)
    expect(token).to be_present
  end
end
```

## Important Notes

1. **Emails are automatically cleared** before each test (configured in `rails_helper.rb`)
2. **No real emails are sent** - all emails are mocked and stored in memory
3. **Emails persist during the test** - you can access them via `ActionMailer::Base.deliveries`
4. **Use `last_email`** to get the most recently sent email
5. **Use `emails_to(address)`** to find all emails sent to a specific address

