require "rails_helper"

RSpec.describe Newsletter::DeliverEmailJob do
  let(:campaign) { create(:campaign, :sending, recipients_count: 1) }
  let(:delivery) { create(:campaign_delivery, campaign:) }

  it "is configured for its queue with bounded retries" do
    expect(described_class.get_sidekiq_options).to include("queue" => :newsletter_delivery, "retry" => 10)
  end

  it "delivers through the gateway" do
    described_class.perform_async(delivery.id)
    described_class.drain

    expect(gateway_deliveries.size).to eq(1)
    expect(delivery.reload).to be_sent
  end

  it "ignores deleted deliveries" do
    expect { described_class.new.perform(0) }.not_to raise_error
  end

  it "raises retryable errors so Sidekiq schedules a retry" do
    email_gateway.fail_next(EmailGateway::RetryableError.new("503"))
    expect { described_class.new.perform(delivery.id) }.to raise_error(EmailGateway::RetryableError)
    expect(delivery.reload).to be_pending
  end

  describe "retry delay (sidekiq_retry_in)" do
    let(:retry_in) { described_class.sidekiq_retry_in_block }

    it "honours the provider Retry-After on rate limits" do
      error = EmailGateway::RateLimitedError.new("429", retry_after: 20)
      expect(retry_in.call(1, error, {})).to be_between(20, 24)
    end

    it "uses exponential backoff for other errors" do
      first = retry_in.call(1, EmailGateway::RetryableError.new, {})
      fifth = retry_in.call(5, EmailGateway::RetryableError.new, {})
      expect(first).to be < 60
      expect(fifth).to be > 600
    end
  end

  describe "when retries are exhausted (sidekiq_retries_exhausted)" do
    it "marks the delivery as failed and finalizes the campaign" do
      job = { "class" => described_class.name, "args" => [delivery.id] }
      described_class.sidekiq_retries_exhausted_block.call(job, EmailGateway::RetryableError.new("still down"))

      expect(delivery.reload).to be_failed
      expect(delivery.last_error).to include("still down")
      expect(campaign.reload).to be_sent
      expect(campaign.failed_count).to eq(1)
    end
  end
end
