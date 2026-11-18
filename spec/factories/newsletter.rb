FactoryBot.define do
  factory :subscriber do
    sequence(:email) { "subscriber#{it}@example.com" }

    trait :confirmed do
      status { :confirmed }
      confirmed_at { 1.day.ago }
    end

    trait :unsubscribed do
      status { :unsubscribed }
      unsubscribed_at { 1.day.ago }
    end
  end

  factory :campaign do
    sequence(:subject) { "Newsletter #{it}" }
    intro { "Novidades da semana" }
    association :created_by, factory: [:user, :admin]

    trait :with_post do
      association :post, :published
    end

    trait :scheduled do
      status { :scheduled }
      scheduled_at { 1.minute.ago }
    end

    trait :queued do
      status { :queued }
      scheduled_at { 1.minute.ago }
      queued_at { Time.current }
    end

    trait :sending do
      status { :sending }
      started_at { Time.current }
    end
  end

  factory :campaign_delivery do
    association :campaign, :sending
    association :subscriber, :confirmed
    email { subscriber&.email || "orphan@example.com" }
  end
end
