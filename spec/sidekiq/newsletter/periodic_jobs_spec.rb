require "rails_helper"

RSpec.describe Newsletter::ScheduleDueCampaignsJob do
  it "enqueues dispatch for due campaigns only" do
    due = create(:campaign, :scheduled, scheduled_at: 1.minute.ago)
    future = create(:campaign, :scheduled, scheduled_at: 1.hour.from_now)

    described_class.new.perform

    expect(due.reload).to be_queued
    expect(future.reload).to be_scheduled
    expect(Newsletter::DispatchCampaignJob.jobs.map { it["args"] }).to eq([[due.id]])
  end

  it "does not enqueue the same campaign twice across runs" do
    create(:campaign, :scheduled)
    2.times { described_class.new.perform }
    expect(Newsletter::DispatchCampaignJob.jobs.size).to eq(1)
  end

  it "re-enqueues campaigns stuck in queued (lost dispatch job)" do
    stuck = create(:campaign, :queued, queued_at: 20.minutes.ago)
    described_class.new.perform

    expect(Newsletter::DispatchCampaignJob.jobs.map { it["args"] }).to eq([[stuck.id]])
    expect(stuck.reload.queued_at).to be > 1.minute.ago
  end

  it "is registered in the cron schedule" do
    schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))
    expect(schedule.values.map { it["class"] }).to include(described_class.name, Newsletter::RecoverStuckDeliveriesJob.name)
  end
end

RSpec.describe Newsletter::RecoverStuckDeliveriesJob do
  it "re-enqueues deliveries abandoned in 'sending'" do
    campaign = create(:campaign, :sending)
    stuck = create(:campaign_delivery, campaign:, status: :sending, locked_at: 30.minutes.ago)
    create(:campaign_delivery, campaign:, status: :sending, locked_at: 1.minute.ago) # still in flight
    create(:campaign_delivery, campaign:) # pending, handled by Sidekiq retries

    described_class.new.perform

    expect(Newsletter::DeliverEmailJob.jobs.map { it["args"] }).to eq([[stuck.id]])
  end
end

RSpec.describe Newsletter::DispatchCampaignJob do
  it "runs the dispatcher for the campaign" do
    create(:subscriber, :confirmed)
    campaign = create(:campaign, :queued)

    described_class.perform_async(campaign.id)
    described_class.drain

    expect(campaign.reload).to be_sending
    expect(Newsletter::DeliverEmailJob.jobs.size).to eq(1)
  end

  it ".enqueue_deliveries pushes all jobs in a single bulk call" do
    expect(Sidekiq::Client).to receive(:push_bulk).once.and_call_original
    described_class.enqueue_deliveries([1, 2, 3])
    expect(Newsletter::DeliverEmailJob.jobs.map { it["args"] }).to eq([[1], [2], [3]])
  end
end
