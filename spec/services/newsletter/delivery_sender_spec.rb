require "rails_helper"

RSpec.describe Newsletter::DeliverySender do
  let(:campaign) { create(:campaign, :sending, :with_post, recipients_count: 1) }
  let(:delivery) { create(:campaign_delivery, campaign:) }

  def send_delivery(record = delivery)
    described_class.call(CampaignDelivery.find(record.id), logger: Logger.new(nil))
  end

  it "sends the e-mail with the delivery idempotency key and records the provider id" do
    expect(send_delivery).to eq(:sent)

    message = gateway_deliveries.sole
    expect(message.to).to eq([delivery.email])
    expect(message.idempotency_key).to eq(delivery.idempotency_key)
    expect(delivery.reload).to be_sent
    expect(delivery.provider_message_id).to eq("test-1")
    expect(campaign.reload).to be_sent
    expect(campaign.sent_count).to eq(1)
  end

  it "does nothing when the delivery was already sent (duplicate job)" do
    send_delivery
    expect(send_delivery).to eq(:not_claimed)
    expect(gateway_deliveries.size).to eq(1)
    expect(campaign.reload.sent_count).to eq(1)
  end

  it "does nothing while another worker holds the delivery" do
    CampaignDelivery.find(delivery.id).claim!
    expect(send_delivery).to eq(:not_claimed)
    expect(gateway_deliveries).to be_empty
  end

  it "skips subscribers who unsubscribed after the dispatch" do
    delivery.subscriber.unsubscribe!
    expect(send_delivery).to eq(:skipped)
    expect(gateway_deliveries).to be_empty
    expect(delivery.reload).to be_skipped
    expect(campaign.reload).to be_sent
  end

  it "marks permanent errors as failed without raising (no retry)" do
    email_gateway.fail_next(EmailGateway::PermanentError.new("invalid recipient", status: 422))

    expect(send_delivery).to eq(:failed)
    expect(delivery.reload).to be_failed
    expect(delivery.last_error).to include("invalid recipient")
    expect(campaign.reload.failed_count).to eq(1)
    expect(campaign).to be_sent
  end

  it "releases the delivery and re-raises retryable errors so Sidekiq retries" do
    email_gateway.fail_next(EmailGateway::RetryableError.new("timeout"))

    expect { send_delivery }.to raise_error(EmailGateway::RetryableError)
    expect(delivery.reload).to be_pending
    expect(delivery.attempts).to eq(1)
    expect(delivery.last_error).to include("timeout")
    expect(campaign.reload).to be_sending

    expect(send_delivery).to eq(:sent) # the retry
    expect(delivery.reload.attempts).to eq(2)
    expect(gateway_deliveries.size).to eq(1)
  end

  it "also releases the row on unexpected errors (e.g. template bug)" do
    allow(NewsletterMailer).to receive(:with).and_raise(NoMethodError, "boom")
    expect { send_delivery }.to raise_error(NoMethodError)
    expect(delivery.reload).to be_pending
  end

  it "relies on the provider idempotency key when a crash happened after sending" do
    # 1st attempt: e-mail accepted by the provider, but the worker dies before mark_sent!.
    allow_any_instance_of(CampaignDelivery).to receive(:mark_sent!).and_raise(SignalException, "KILL")
    expect { send_delivery }.to raise_error(SignalException)
    allow_any_instance_of(CampaignDelivery).to receive(:mark_sent!).and_call_original

    # Row stays "sending"; after the lock timeout the recovery job/retry claims it again.
    travel CampaignDelivery::LOCK_TIMEOUT + 1.minute
    expect(send_delivery).to eq(:sent)

    # Same idempotency key both times -> the (test) provider only delivered once.
    expect(gateway_deliveries.size).to eq(1)
    expect(delivery.reload.attempts).to eq(2)
  end
end
