FactoryBot.define do
  factory :event_registration do
    user { nil }
    event_post { nil }
    status { 1 }
    registered_at { "2025-10-25 07:33:04" }
  end
end
