FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@university.edu" }
    sequence(:name) { |n| "User #{n}" }
    phone_number { "555-0#{rand(100..999)}" }
    e_score { rand(0..500) }

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
  end
end
