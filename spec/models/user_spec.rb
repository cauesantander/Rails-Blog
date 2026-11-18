require "rails_helper"

RSpec.describe User do
  subject { build(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_uniqueness_of(:email_address).ignoring_case_sensitivity }
    it { is_expected.to validate_length_of(:password).is_at_least(8).is_at_most(72) }
    it { is_expected.to have_secure_password }

    it "rejects malformed e-mails" do
      expect(build(:user, email_address: "not-an-email")).not_to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:comments).dependent(:destroy) }
    it { is_expected.to have_many(:posts).with_foreign_key(:author_id) }
  end

  it "normalizes the e-mail address" do
    user = create(:user, email_address: "  Ana@Example.COM ")
    expect(user.email_address).to eq("ana@example.com")
  end

  it "is a reader by default and only accepts known roles" do
    expect(build(:user)).to be_reader
    expect(build(:user, role: "superuser")).not_to be_valid
  end

  it "authenticates by e-mail and password" do
    user = create(:user, email_address: "ana@example.com", password: "password123")
    expect(User.authenticate_by(email_address: "ana@example.com", password: "password123")).to eq(user)
    expect(User.authenticate_by(email_address: "ana@example.com", password: "wrong-pass")).to be_nil
  end

  describe "avatar" do
    it "accepts images" do
      user = build(:user)
      user.avatar.attach(io: StringIO.new("fake-png"), filename: "a.png", content_type: "image/png")
      expect(user).to be_valid
    end

    it "rejects other content types" do
      user = build(:user)
      user.avatar.attach(io: StringIO.new("%PDF"), filename: "a.pdf", content_type: "application/pdf")
      expect(user).not_to be_valid
      expect(user.errors[:avatar]).to be_present
    end

    it "rejects files larger than 2 MB" do
      user = build(:user)
      user.avatar.attach(io: StringIO.new("0" * (User::AVATAR_MAX_SIZE + 1)), filename: "a.png", content_type: "image/png")
      expect(user).not_to be_valid
    end
  end
end
