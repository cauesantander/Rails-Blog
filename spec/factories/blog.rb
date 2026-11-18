FactoryBot.define do
  factory :category do
    sequence(:name) { "Categoria #{it}" }
  end

  factory :tag do
    sequence(:name) { "tag#{it}" }
  end

  factory :post do
    association :author, factory: :user
    sequence(:title) { "Post número #{it}" }
    body { "Conteúdo em **markdown**." }

    trait :published do
      status { :published }
      published_at { 1.hour.ago }
    end

    trait :scheduled do
      status { :published }
      published_at { 1.day.from_now }
    end
  end

  factory :comment do
    association :post, :published
    user
    body { "Muito bom!" }
  end
end
