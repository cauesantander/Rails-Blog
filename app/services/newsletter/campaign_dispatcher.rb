module Newsletter
  # Turns a queued campaign into one CampaignDelivery per confirmed subscriber and
  # enqueues one DeliverEmailJob per delivery, in batches.
  #
  # Idempotent by design, so the job that runs it can be retried at any point:
  # - rows are inserted with INSERT ... ON CONFLICT DO NOTHING on (campaign_id, subscriber_id);
  # - only deliveries still "pending" are enqueued, and a duplicated job is harmless
  #   because DeliverySender claims each row atomically before sending.
  class CampaignDispatcher
    INSERT_BATCH_SIZE = 1_000

    def self.call(campaign, **) = new(campaign, **).call

    def initialize(campaign, batch_size: Rails.configuration.x.newsletter.batch_size,
                   batch_interval: Rails.configuration.x.newsletter.batch_interval, logger: Rails.logger)
      @campaign = campaign
      @batch_size = batch_size
      @batch_interval = batch_interval
      @logger = logger
    end

    def call
      unless @campaign.queued? || @campaign.sending?
        @logger.info("[Newsletter] dispatch skipped campaign_id=#{@campaign.id} status=#{@campaign.status}")
        return
      end

      recipients = materialize_deliveries
      @campaign.mark_sending!(recipients_count: recipients)
      batches = enqueue_pending_deliveries
      @logger.info("[Newsletter] dispatched campaign_id=#{@campaign.id} recipients=#{recipients} batches=#{batches}")

      # Campaign with no recipients (or everything already processed) finishes right away.
      @campaign.finalize_if_complete!
    end

    private
      # Phase 1: snapshot the audience. Uses insert_all (one INSERT per 1000 rows) instead of
      # create! per row; validations/callbacks are skipped on purpose, the DB constraints guard us.
      def materialize_deliveries
        Subscriber.confirmed.select(:id, :email).find_in_batches(batch_size: INSERT_BATCH_SIZE) do |subscribers|
          rows = subscribers.map do |subscriber|
            { campaign_id: @campaign.id, subscriber_id: subscriber.id, email: subscriber.email, status: "pending" }
          end
          CampaignDelivery.insert_all(rows, unique_by: %i[campaign_id subscriber_id])
        end
        @campaign.deliveries.count
      end

      # Phase 2: fan-out. Each batch is pushed to Redis in a single round trip (push_bulk) and
      # scheduled `batch_interval` after the previous one, spreading the load on the provider.
      def enqueue_pending_deliveries
        batches = 0
        @campaign.deliveries.pending.in_batches(of: @batch_size).each_with_index do |relation, index|
          DispatchCampaignJob.enqueue_deliveries(relation.ids, at: Time.current + (index * @batch_interval))
          batches += 1
        end
        batches
      end
  end
end
