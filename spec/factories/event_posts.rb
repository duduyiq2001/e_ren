FactoryBot.define do
  factory :event_post do
    sequence(:name) { |n| "Event #{n}" }
    description { "This is a test event description." }
    association :event_category
    association :organizer, factory: :user
    capacity { 20 }
    event_time { 2.days.from_now }
    location_name { "Test Location" }
    google_maps_url { nil }
    latitude { 37.7749 }
    longitude { -122.4194 }
    google_place_id { nil }
    formatted_address { nil }
    registrations_count { 0 }
    requires_approval {false}
    trait :need_approve do
      requires_approval {true}
    end
    trait :today do
      event_time { 1.day.from_now.change(hour: 18) }
    end

    trait :tomorrow do
      event_time { 1.day.from_now.change(hour: 14) }
    end

    trait :two_days_from_now do
      event_time { 2.days.from_now.change(hour: 16) }
    end

    trait :this_week do
      event_time {
        # Try Thursday 7 PM of current week
        thursday = Time.current.beginning_of_week + 3.days + 19.hours

        # If Thursday is in the past (we're late in the week), use tomorrow instead
        # This keeps it in future but might be next week if run on Sunday
        thursday > Time.current ? thursday : 1.day.from_now.change(hour: 19)
      }
    end

    trait :next_week do
      event_time { 1.week.from_now.change(hour: 15) }
    end

    trait :past do
      event_time { 2.days.ago }
    end

    trait :with_attendees do
      transient do
        attendees_count { 3 }
      end

      after(:create) do |event_post, evaluator|
        create_list(:event_registration, evaluator.attendees_count, event_post: event_post)
      end
    end

    trait :full do
      registrations_count { 20 }
      capacity { 20 }
    end

    trait :near_location do
      latitude { 37.7749 }
      longitude { -122.4194 }
      location_name { "San Francisco" }
    end

    trait :far_location do
      latitude { 40.7128 }
      longitude { -74.0060 }
      location_name { "New York" }
    end
  end
end
