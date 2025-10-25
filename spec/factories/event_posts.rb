FactoryBot.define do
  factory :event_post do
    name { "MyString" }
    description { "MyText" }
    event_category { nil }
    organizer_id { "" }
    capacity { 1 }
    event_time { "2025-10-25 07:26:14" }
    location_name { "MyString" }
    google_maps_url { "MyString" }
    latitude { "9.99" }
    longitude { "9.99" }
    google_place_id { "MyString" }
    formatted_address { "MyText" }
    registrations_count { 1 }
  end
end
