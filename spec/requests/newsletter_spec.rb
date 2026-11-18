require "rails_helper"

RSpec.describe "Newsletter subscription" do
  it "subscribes (double opt-in) and sends the confirmation e-mail" do
    expect {
      post newsletter_subscriptions_path, params: { email: "ana@example.com" }
    }.to change(Subscriber, :count).by(1).and have_enqueued_mail(SubscriptionMailer, :confirmation)

    expect(Subscriber.last).to be_pending
    expect(response).to redirect_to(root_path)
  end

  it "answers the same for already confirmed e-mails (no enumeration)" do
    create(:subscriber, :confirmed, email: "ana@example.com")
    post newsletter_subscriptions_path, params: { email: "ana@example.com" }
    expect(flash[:notice]).to include("Quase lá")
  end

  it "rejects invalid e-mails" do
    post newsletter_subscriptions_path, params: { email: "invalid" }
    expect(flash[:alert]).to be_present
    expect(Subscriber.count).to eq(0)
  end

  it "confirms with the token from the e-mail" do
    subscriber = create(:subscriber)
    get newsletter_confirmation_path(token: subscriber.generate_token_for(:confirmation))
    expect(subscriber.reload).to be_confirmed
  end

  it "rejects tampered confirmation tokens" do
    get newsletter_confirmation_path(token: "tampered")
    expect(flash[:alert]).to be_present
  end

  describe "unsubscribe" do
    let(:subscriber) { create(:subscriber, :confirmed) }

    it "GET only shows a confirmation page (safe against link prefetchers)" do
      get newsletter_unsubscribe_path(token: subscriber.unsubscribe_token)
      expect(response).to have_http_status(:ok)
      expect(subscriber.reload).to be_confirmed
    end

    it "POST unsubscribes" do
      post newsletter_unsubscribe_path(token: subscriber.unsubscribe_token)
      expect(subscriber.reload).to be_unsubscribed
    end

    it "supports RFC 8058 one-click unsubscribe" do
      post newsletter_unsubscribe_path(token: subscriber.unsubscribe_token),
           params: "List-Unsubscribe=One-Click", headers: { "Content-Type" => "application/x-www-form-urlencoded", "Accept" => "*/*" }
      expect(subscriber.reload).to be_unsubscribed
    end

    it "404s for unknown tokens" do
      get newsletter_unsubscribe_path(token: "nope")
      expect(response).to have_http_status(:not_found)
    end
  end
end
