module Newsletter
  # Step 1 of a campaign send: builds the recipient list and fans out DeliverEmailJob.
  # Enqueued by Campaign#enqueue_dispatch! (admin "send now" or the scheduler).
  class DispatchCampaignJob
    include Sidekiq::Job
    sidekiq_options queue: :newsletter_dispatch, retry: 5

    def perform(campaign_id)
      campaign = Campaign.find_by(id: campaign_id)
      return Sidekiq.logger.warn("[Newsletter] campaign #{campaign_id} not found") unless campaign

      CampaignDispatcher.call(campaign)
    end

    # One Redis round trip per batch instead of one per job.
    def self.enqueue_deliveries(delivery_ids, at: nil)
      return if delivery_ids.empty?

      payload = { "class" => DeliverEmailJob, "args" => delivery_ids.map { [it] } }
      payload["at"] = at.to_f if at && at > Time.current
      Sidekiq::Client.push_bulk(payload)
    end
  end
end
