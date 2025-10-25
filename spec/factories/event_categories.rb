FactoryBot.define do
  factory :event_category do
    sequence(:name) { |n| "Category #{n}" }
    icon { "🎉" }
    color { "##{SecureRandom.hex(3)}" }

    trait :sports do
      name { "Sports & Recreation" }
      icon { "⚽" }
      color { "#FF5733" }
    end

    trait :social do
      name { "Social & Networking" }
      icon { "🎊" }
      color { "#33C3FF" }
    end

    trait :academic do
      name { "Academic & Career" }
      icon { "📚" }
      color { "#4CAF50" }
    end

    trait :food do
      name { "Food & Dining" }
      icon { "🍕" }
      color { "#FFC107" }
    end
  end
end
