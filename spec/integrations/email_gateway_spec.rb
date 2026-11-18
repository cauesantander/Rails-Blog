require "rails_helper"

RSpec.describe EmailGateway do
  describe ".build" do
    it "builds the adapter named by EMAIL_PROVIDER" do
      expect(described_class.build("log")).to be_a(EmailGateway::LogAdapter)
      expect(described_class.build("test")).to be_a(EmailGateway::TestAdapter)
    end

    it "fails fast on unknown providers" do
      expect { described_class.build("smtp") }.to raise_error(EmailGateway::ConfigurationError)
    end
  end

  describe EmailGateway::Message do
    it ".from_mail extracts parts and forwarded headers from an ActionMailer message" do
      delivery = create(:campaign_delivery, campaign: create(:campaign, :sending, :with_post))
      mail = NewsletterMailer.with(delivery:).campaign_email.message

      message = described_class.from_mail(mail, idempotency_key: "k1")

      expect(message.to).to eq([delivery.email])
      expect(message.subject).to eq(delivery.campaign.subject)
      expect(message.html).to include(delivery.campaign.post.title)
      expect(message.text).to include("Cancelar inscrição")
      expect(message.headers.keys).to include("List-Unsubscribe", "List-Unsubscribe-Post", "X-Campaign-Id")
      expect(message.idempotency_key).to eq("k1")
    end
  end

  describe EmailGateway::LogAdapter do
    it "writes the e-mail to disk and never calls the network" do
      dir = Rails.root.join("tmp/test-mails")
      adapter = described_class.new(logger: Logger.new(nil), dir:)
      result = adapter.deliver(EmailGateway::Message.new(to: "a@b.c", from: "x@y.z", subject: "s", html: "<b>oi</b>"))

      expect(result.message_id).to start_with("log-")
      expect(File.read(dir.join("#{result.message_id}.html"))).to eq("<b>oi</b>")
    ensure
      FileUtils.rm_rf(dir)
    end

    it "can simulate provider failures" do
      adapter = described_class.new(logger: Logger.new(nil), failure_rate: 1.0)
      expect { adapter.deliver(EmailGateway::Message.new(to: "a@b.c", from: "x", subject: "s")) }
        .to raise_error(EmailGateway::RetryableError, /simulated/)
    end
  end

  describe EmailGateway::ActionMailerDelivery do
    it "lets ActionMailer deliver through the configured adapter" do
      user = create(:user)
      mail = PasswordsMailer.reset(user)
      mail.delivery_method(described_class)

      mail.deliver_now

      expect(gateway_deliveries.map(&:to)).to eq([[user.email_address]])
      expect(gateway_deliveries.first.subject).to eq("Redefinição de senha")
    end
  end
end
