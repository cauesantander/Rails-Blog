require "rails_helper"

# Full newsletter lifecycle with every job executed by Sidekiq's test harness:
# admin schedules -> cron picks it up -> dispatcher fans out -> deliveries (with failures).
RSpec.describe "Newsletter campaign flow" do
  let!(:subscribers) { create_list(:subscriber, 5, :confirmed) }
  let(:campaign) { create(:campaign, :with_post) }

  def run_all_jobs
    # drain_all keeps running until no job is left, including jobs enqueued by other jobs.
    Sidekiq::Job.drain_all
  end

  it "sends one e-mail per confirmed subscriber and closes the campaign" do
    campaign.schedule!(at: 1.minute.ago)
    Newsletter::ScheduleDueCampaignsJob.perform_async
    run_all_jobs

    expect(gateway_deliveries.map(&:to).flatten).to match_array(subscribers.map(&:email))
    expect(campaign.reload).to be_sent
    expect(campaign.attributes.slice("recipients_count", "sent_count", "failed_count"))
      .to eq("recipients_count" => 5, "sent_count" => 5, "failed_count" => 0)
  end

  it "survives transient provider failures through retries without duplicating e-mails" do
    campaign.schedule!(at: 1.minute.ago)
    campaign.enqueue_dispatch!
    Newsletter::DispatchCampaignJob.drain

    email_gateway.fail_next(EmailGateway::RetryableError.new("timeout"), times: 2)
    failures = 0
    # Simulate Sidekiq's retry loop: a failing job is run again later.
    until Newsletter::DeliverEmailJob.jobs.empty?
      job = Newsletter::DeliverEmailJob.jobs.shift
      begin
        Newsletter::DeliverEmailJob.new.perform(*job["args"])
      rescue EmailGateway::RetryableError
        failures += 1
        Newsletter::DeliverEmailJob.jobs << job
      end
    end

    expect(failures).to eq(2)
    expect(gateway_deliveries.size).to eq(5)
    expect(campaign.reload).to be_sent
    expect(campaign.sent_count).to eq(5)
    expect(campaign.deliveries.sum(:attempts)).to eq(7)
  end

  it "records permanent failures and allows the admin to retry them" do
    campaign.schedule!(at: 1.minute.ago)
    campaign.enqueue_dispatch!
    email_gateway.fail_next(EmailGateway::PermanentError.new("invalid address"), times: 1)
    run_all_jobs

    expect(campaign.reload.attributes.slice("status", "sent_count", "failed_count"))
      .to eq("status" => "sent", "sent_count" => 4, "failed_count" => 1)

    expect(campaign.retry_failed_deliveries!).to eq(1)
    run_all_jobs

    expect(campaign.reload.attributes.slice("status", "sent_count", "failed_count"))
      .to eq("status" => "sent", "sent_count" => 5, "failed_count" => 0)
    expect(gateway_deliveries.size).to eq(5)
  end

  it "never sends twice when the dispatch job runs more than once" do
    campaign.schedule!(at: 1.minute.ago)
    campaign.enqueue_dispatch!
    Newsletter::DispatchCampaignJob.perform_async(campaign.id) # duplicate (e.g. recovered queued campaign)
    run_all_jobs

    expect(gateway_deliveries.size).to eq(5)
    expect(campaign.deliveries.count).to eq(5)
  end
end
