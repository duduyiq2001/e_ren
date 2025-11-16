# frozen_string_literal: true

Devise.setup do |config|
  # ==> Mailer Configuration
  config.mailer_sender = 'noreply@wustl.edu'

  # ==> ORM configuration
  require 'devise/orm/active_record'

  # ==> Configuration for any authentication mechanism
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  # ==> Configuration for :database_authenticatable
  config.stretches = Rails.env.test? ? 1 : 12

  # ==> Configuration for :validatable
  config.password_length = 6..128

  # ==> Configuration for :recoverable
  config.reset_password_within = 6.hours

  # ==> Configuration for :rememberable
  config.expire_all_remember_me_on_sign_out = true

  # ==> Configuration for :reconfirmable
  config.reconfirmable = true

  # ==> Navigation configuration
  config.sign_out_via = :delete
end
