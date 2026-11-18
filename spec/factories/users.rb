FactoryBot.define do
  factory :user do
    sequence(:email_address) { "user#{it}@example.com" }
    name { Faker::Name.name }
    password { "password123" }

    trait :admin do
      role { :admin }
    end
  end
end
