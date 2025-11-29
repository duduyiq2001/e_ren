FactoryBot.define do
  factory :admin_audit_log do
    association :admin_user, factory: :user, role: :super_admin
    action { 'delete' }
    target_type { 'User' }
    target_id { 1 }
    metadata { {} }
    ip_address { '127.0.0.1' }
    user_agent { 'Mozilla/5.0' }

    trait :restore do
      action { 'restore' }
    end

    trait :for_user do
      target_type { 'User' }
    end

    trait :for_event_post do
      target_type { 'EventPost' }
    end
  end
end

