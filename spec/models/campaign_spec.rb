require "rails_helper"

RSpec.describe Campaign do
  describe "validations" do
    subject { build(:campaign) }

    it { is_expected.to validate_presence_of(:subject) }
    it { is_expected.to belong_to(:created_by).class_name("User") }
    it { is_expected.to belong_to(:post).optional }

    it "requires the post to be visible when scheduling" do
      campaign = create(:campaign, post: create(:post))
      expect { campaign.schedule! }.to raise_error(ActiveRecord::RecordInvalid, /publicado/)
    end
  end

  describe "#schedule!" do
    it "moves a draft to scheduled" do
      campaign = create(:campaign)
      at = 1.day.from_now
      campaign.schedule!(at:)
      expect(campaign).to be_scheduled
      expect(campaign.scheduled_at).to be_within(1.second).of(at)
    end

    it "refuses campaigns that already left draft" do
      expect { create(:campaign, :sending).schedule! }.to raise_error(Campaign::InvalidTransition)
    end
  end

  describe "#enqueue_dispatch!" do
    it "moves scheduled -> queued and enqueues the dispatch job once" do
      campaign = create(:campaign, :scheduled)

      expect(campaign.enqueue_dispatch!).to be(true)
      expect(campaign.reload).to be_queued
      expect(campaign.queued_at).to be_present
      expect(Newsletter::DispatchCampaignJob.jobs.map { it["args"] }).to eq([[campaign.id]])
    end

    it "is idempotent: a second call (or a concurrent scheduler) does nothing" do
      campaign = create(:campaign, :scheduled)
      stale_copy = Campaign.find(campaign.id) # simulates another process holding the old state

      campaign.enqueue_dispatch!
      expect(stale_copy.enqueue_dispatch!).to be(false)
      expect(Newsletter::DispatchCampaignJob.jobs.size).to eq(1)
    end
  end

  describe "#unschedule! / #cancel!" do
    it "returns a scheduled campaign to draft" do
      campaign = create(:campaign, :scheduled)
      campaign.unschedule!
      expect(campaign).to be_draft
    end

    it "cancels drafts but not campaigns already sending" do
      expect(create(:campaign).tap(&:cancel!)).to be_canceled
      expect { create(:campaign, :sending).cancel! }.to raise_error(Campaign::InvalidTransition)
    end
  end

  describe "#finalize_if_complete!" do
    let(:campaign) { create(:campaign, :sending) }

    it "keeps sending while deliveries are pending" do
      create(:campaign_delivery, campaign:)
      expect(campaign.finalize_if_complete!).to be(false)
      expect(campaign.reload).to be_sending
    end

    it "marks as sent when every delivery is finished, only once" do
      create(:campaign_delivery, campaign:, status: :sent)
      create(:campaign_delivery, campaign:, status: :failed)

      expect(campaign.finalize_if_complete!).to be(true)
      expect(campaign).to be_sent
      expect(campaign.finished_at).to be_present
      expect(campaign.finalize_if_complete!).to be(false)
    end
  end

  describe "#retry_failed_deliveries!" do
    it "resets failed deliveries, fixes counters and re-enqueues them" do
      campaign = create(:campaign, status: :sent, recipients_count: 2, sent_count: 1, failed_count: 1)
      create(:campaign_delivery, campaign:, status: :sent)
      failed = create(:campaign_delivery, campaign:, status: :failed)

      expect(campaign.retry_failed_deliveries!).to eq(1)
      expect(failed.reload).to be_pending
      expect(campaign.reload).to be_sending
      expect(campaign.failed_count).to eq(0)
      expect(Newsletter::DeliverEmailJob.jobs.map { it["args"] }).to eq([[failed.id]])
    end

    it "is not allowed before the campaign is sent" do
      expect { create(:campaign).retry_failed_deliveries! }.to raise_error(Campaign::InvalidTransition)
    end
  end

  describe "scopes" do
    it ".due returns scheduled campaigns whose time has come" do
      due = create(:campaign, :scheduled, scheduled_at: 1.minute.ago)
      create(:campaign, :scheduled, scheduled_at: 1.hour.from_now)
      create(:campaign)
      expect(Campaign.due).to contain_exactly(due)
    end

    it ".stale_queued returns campaigns queued for too long" do
      stale = create(:campaign, :queued, queued_at: 11.minutes.ago)
      create(:campaign, :queued, queued_at: 1.minute.ago)
      expect(Campaign.stale_queued).to contain_exactly(stale)
    end
  end
end
