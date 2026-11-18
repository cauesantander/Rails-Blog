require "rails_helper"

RSpec.describe Subscriber do
  subject { build(:subscriber) }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).ignoring_case_sensitivity }

  it "generates an unsubscribe token" do
    expect(create(:subscriber).unsubscribe_token).to be_present
  end

  describe ".subscribe" do
    it "creates a pending subscriber and sends the confirmation e-mail" do
      expect {
        subscriber = Subscriber.subscribe(" New@Example.com ")
        expect(subscriber).to be_pending
        expect(subscriber.email).to eq("new@example.com")
      }.to change(Subscriber, :count).by(1)
        .and have_enqueued_mail(SubscriptionMailer, :confirmation)
    end

    it "does nothing for an already confirmed e-mail" do
      create(:subscriber, :confirmed, email: "ana@example.com")
      expect {
        expect(Subscriber.subscribe("ana@example.com")).to be_confirmed
      }.not_to have_enqueued_mail(SubscriptionMailer, :confirmation)
    end

    it "reactivates an unsubscribed address as pending" do
      subscriber = create(:subscriber, :unsubscribed, email: "ana@example.com")
      expect { Subscriber.subscribe("ana@example.com") }.to have_enqueued_mail(SubscriptionMailer, :confirmation)
      expect(subscriber.reload).to be_pending
    end

    it "returns an invalid record for bad e-mails without sending anything" do
      expect {
        expect(Subscriber.subscribe("nope").errors[:email]).to be_present
      }.not_to have_enqueued_mail
    end

    it "links the subscription to the logged user" do
      user = create(:user)
      expect(Subscriber.subscribe("x@example.com", user:).user).to eq(user)
    end
  end

  describe "confirmation token" do
    it "confirms with a valid token and becomes single-use" do
      subscriber = create(:subscriber)
      token = subscriber.generate_token_for(:confirmation)

      expect(Subscriber.find_by_token_for(:confirmation, token)).to eq(subscriber)
      subscriber.confirm!
      expect(Subscriber.find_by_token_for(:confirmation, token)).to be_nil
    end

    it "expires after 3 days" do
      token = create(:subscriber).generate_token_for(:confirmation)
      travel 4.days
      expect(Subscriber.find_by_token_for(:confirmation, token)).to be_nil
    end
  end

  it "#unsubscribe! records the time" do
    subscriber = create(:subscriber, :confirmed)
    subscriber.unsubscribe!
    expect(subscriber).to be_unsubscribed
    expect(subscriber.unsubscribed_at).to be_present
  end
end
