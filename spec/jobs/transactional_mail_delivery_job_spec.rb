require "rails_helper"

RSpec.describe TransactionalMailDeliveryJob do
  let(:user) { create(:user) }

  it "is the job used by deliver_later, on the mailers queue" do
    expect { PasswordsMailer.reset(user).deliver_later }
      .to have_enqueued_job(described_class).on_queue("mailers")
  end

  context "when delivering through EmailGateway" do
    around do |example|
      original = ActionMailer::Base.delivery_method
      ActionMailer::Base.delivery_method = :email_gateway
      example.run
    ensure
      ActionMailer::Base.delivery_method = original
    end

    it "delivers the e-mail" do
      perform_enqueued_jobs { PasswordsMailer.reset(user).deliver_later }
      expect(gateway_deliveries.sole.to).to eq([user.email_address])
    end

    it "schedules a retry on retryable provider errors" do
      email_gateway.fail_next(EmailGateway::RetryableError.new("timeout"))
      PasswordsMailer.reset(user).deliver_later

      expect { perform_enqueued_jobs(only: described_class) }.not_to raise_error
      expect(gateway_deliveries).to be_empty
      expect(described_class).to have_been_enqueued.at_least(:once) # re-enqueued by retry_on
    end

    it "discards the job on permanent errors" do
      email_gateway.fail_next(EmailGateway::PermanentError.new("invalid address"))
      PasswordsMailer.reset(user).deliver_later

      expect { perform_enqueued_jobs }.not_to raise_error
      expect(enqueued_jobs).to be_empty
    end
  end
end
