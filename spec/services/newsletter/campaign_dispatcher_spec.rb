require "rails_helper"

RSpec.describe Newsletter::CampaignDispatcher do
  let(:campaign) { create(:campaign, :queued, :with_post) }

  def dispatch(**options)
    described_class.call(campaign, batch_size: 2, batch_interval: 30.seconds, logger: Logger.new(nil), **options)
  end

  before do
    create_list(:subscriber, 3, :confirmed)
    create(:subscriber)                # pending: not a recipient
    create(:subscriber, :unsubscribed) # left: not a recipient
  end

  it "creates one pending delivery per confirmed subscriber and moves the campaign to sending" do
    dispatch

    expect(campaign.reload).to be_sending
    expect(campaign.recipients_count).to eq(3)
    expect(campaign.started_at).to be_present
    expect(campaign.deliveries.pending.count).to eq(3)
    expect(campaign.deliveries.pluck(:email)).to match_array(Subscriber.confirmed.pluck(:email))
  end

  it "enqueues deliveries in batches, spreading later batches over time" do
    freeze_time do
      dispatch

      jobs = Newsletter::DeliverEmailJob.jobs
      expect(jobs.size).to eq(3)
      immediate, delayed = jobs.partition { it["at"].nil? }
      expect(immediate.size).to eq(2) # first batch runs now
      expect(delayed.map { it["at"] }).to all(be_within(1).of(30.seconds.from_now.to_f))
    end
  end

  it "is idempotent: running twice neither duplicates rows nor sends twice" do
    dispatch
    dispatch

    expect(campaign.deliveries.count).to eq(3)
    expect(campaign.reload.recipients_count).to eq(3)

    # The second run re-enqueues still-pending rows, but each one is claimed only once.
    Newsletter::DeliverEmailJob.drain
    expect(gateway_deliveries.size).to eq(3)
    expect(campaign.reload).to be_sent
  end

  it "finishes immediately when there are no recipients" do
    Subscriber.delete_all
    dispatch
    expect(campaign.reload).to be_sent
    expect(campaign.recipients_count).to eq(0)
  end

  it "ignores campaigns that are not queued/sending (e.g. canceled)" do
    campaign.update_columns(status: "canceled")
    dispatch
    expect(campaign.deliveries).to be_empty
    expect(Newsletter::DeliverEmailJob.jobs).to be_empty
  end
end
