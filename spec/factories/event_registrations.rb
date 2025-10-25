FactoryBot.define do
  factory :event_registration do
    association :user
    association :event_post
    status { :confirmed }
    registered_at { Time.current }

    trait :pending do
      status { :pending }
    end

    trait :confirmed do
      status { :confirmed }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :waitlisted do
      status { :waitlisted }
    end
  end
end
