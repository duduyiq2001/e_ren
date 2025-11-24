FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@wustl.edu" }
    sequence(:name) { |n| "User #{n}" }
    password { "password123" }
    password_confirmation { "password123" }
    phone_number { "555-0#{rand(100..999)}" }
    e_score { rand(0..500) }
    confirmed_at { Time.current }  # Users are confirmed by default

    trait :high_score do
      e_score { rand(400..500) }
    end

    trait :low_score do
      e_score { rand(0..100) }
    end

    trait :with_phone do
      phone_number { "555-0123" }
    end

    trait :without_phone do
      phone_number { nil }
    end

    trait :confirmed do
      confirmed_at { Time.current }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    # Role-based traits (emails auto-sequenced with wustl.edu)
    trait :organizer do
      sequence(:name) { |n| "Organizer #{n}" }
      sequence(:email) { |n| "organizer#{n}@wustl.edu" }
    end

    trait :attendee do
      sequence(:name) { |n| "Attendee #{n}" }
      sequence(:email) { |n| "attendee#{n}@wustl.edu" }
    end

    trait :admin do
      sequence(:name) { |n| "Admin #{n}" }
      sequence(:email) { |n| "admin#{n}@wustl.edu" }
      role { :super_admin }
    end
  end
end
