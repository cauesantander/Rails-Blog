require "rails_helper"

RSpec.describe SubscriptionMailer do
  it "sends a confirmation link that confirms the subscriber" do
    subscriber = create(:subscriber, email: "ana@example.com")
    mail = described_class.with(subscriber:).confirmation

    expect(mail.to).to eq(["ana@example.com"])
    expect(mail.subject).to include("Confirme")
    token = mail.text_part.decoded[%r{/newsletter/confirm/([^\s]+)}, 1]
    expect(Subscriber.find_by_token_for(:confirmation, token)).to eq(subscriber)
  end
end

RSpec.describe NewsletterMailer do
  let(:delivery) { create(:campaign_delivery, campaign: create(:campaign, :sending, :with_post, intro: "Oi pessoal")) }
  let(:mail) { described_class.with(delivery:).campaign_email }

  it "renders the campaign for the recipient" do
    expect(mail.to).to eq([delivery.email])
    expect(mail.subject).to eq(delivery.campaign.subject)
    expect(mail.html_part.decoded).to include("Oi pessoal", delivery.campaign.post.title)
  end

  it "includes a personal unsubscribe link and RFC 8058 headers" do
    url = "http://example.com/newsletter/unsubscribe/#{delivery.subscriber.unsubscribe_token}"
    expect(mail.text_part.decoded).to include(url)
    expect(mail["List-Unsubscribe"].value).to eq("<#{url}>")
    expect(mail["List-Unsubscribe-Post"].value).to eq("List-Unsubscribe=One-Click")
  end
end

RSpec.describe PasswordsMailer do
  it "sends the reset link" do
    user = create(:user)
    mail = described_class.reset(user)
    expect(mail.to).to eq([user.email_address])
    expect(mail.text_part.decoded).to include("/passwords/")
  end
end
