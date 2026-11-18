require "rails_helper"

RSpec.describe CampaignDelivery do
  let(:campaign) { create(:campaign, :sending, recipients_count: 1) }
  let(:delivery) { create(:campaign_delivery, campaign:) }

  it "enforces one delivery per subscriber per campaign at the database level" do
    duplicate = delivery.dup
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "exposes a stable idempotency key" do
    expect(delivery.idempotency_key).to eq("campaign-delivery-#{delivery.id}")
  end

  describe "#claim!" do
    it "moves pending -> sending, increments attempts and locks the row" do
      expect(delivery.claim!).to be(true)
      expect(delivery).to be_sending
      expect(delivery.attempts).to eq(1)
      expect(delivery.locked_at).to be_present
    end

    it "lets only one caller win" do
      other_worker_copy = CampaignDelivery.find(delivery.id)
      expect(delivery.claim!).to be(true)
      expect(other_worker_copy.claim!).to be(false)
    end

    it "never claims finished deliveries" do
      %i[sent failed skipped].each do |status|
        expect(create(:campaign_delivery, campaign:, status:).claim!).to be(false)
      end
    end

    it "reclaims deliveries abandoned in 'sending' after the lock timeout" do
      delivery.claim!
      expect(delivery.claim!).to be(false)

      travel CampaignDelivery::LOCK_TIMEOUT + 1.minute
      expect(delivery.claim!).to be(true)
      expect(delivery.attempts).to eq(2)
    end
  end

  describe "#mark_sent!" do
    it "stores the provider id and increments the campaign counter exactly once" do
      delivery.claim!
      expect(delivery.mark_sent!("re_123")).to be(true)
      expect(delivery.mark_sent!("re_123")).to be(false)

      expect(delivery).to be_sent
      expect(delivery.provider_message_id).to eq("re_123")
      expect(campaign.reload.sent_count).to eq(1)
    end
  end

  describe "#mark_failed!" do
    it "records the error and increments failed_count once" do
      delivery.claim!
      delivery.mark_failed!(EmailGateway::PermanentError.new("invalid address"))
      delivery.mark_failed!(EmailGateway::PermanentError.new("again"))

      expect(delivery).to be_failed
      expect(delivery.last_error).to eq("EmailGateway::PermanentError: invalid address")
      expect(campaign.reload.failed_count).to eq(1)
    end
  end

  describe "#release!" do
    it "puts the delivery back to pending with the error message" do
      delivery.claim!
      delivery.release!(EmailGateway::RetryableError.new("timeout"))
      expect(delivery).to be_pending
      expect(delivery.locked_at).to be_nil
      expect(delivery.last_error).to include("timeout")
    end
  end
end
