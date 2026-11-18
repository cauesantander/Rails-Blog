require "rails_helper"

RSpec.describe Category do
  # Persisted: the slug is generated in a callback, which shoulda's uniqueness matcher skips.
  subject { create(:category) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name) }

  it "derives the slug from the name" do
    expect(create(:category, name: "Programação Funcional").slug).to eq("programacao-funcional")
  end

  it "nullifies the category of its posts when destroyed" do
    category = create(:category)
    post = create(:post, category:)
    category.destroy!
    expect(post.reload.category).to be_nil
  end
end

RSpec.describe Tag do
  it "normalizes names to lowercase" do
    expect(create(:tag, name: " Rails ").name).to eq("rails")
  end

  it "is unique per name" do
    create(:tag, name: "ruby")
    expect(build(:tag, name: "RUBY")).not_to be_valid
  end
end
