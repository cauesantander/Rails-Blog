module Newsletter
  # Periodic job (every 10 minutes). Open-source Sidekiq fetches jobs with BRPOP: if a
  # worker process is killed (OOM, kill -9) while running a job, that job is gone.
  # A delivery left in "sending" past CampaignDelivery::LOCK_TIMEOUT is the trace of such a
  # crash; re-enqueueing it is safe because claim! accepts stale locks and the provider
  # deduplicates by idempotency key.
  class RecoverStuckDeliveriesJob
    include Sidekiq::Job
    sidekiq_options queue: :newsletter_dispatch, retry: false # the next cron tick is the retry

    def perform
      ids = CampaignDelivery.stale.limit(10_000).pluck(:id)
      return if ids.empty?

      ids.each_slice(1_000) { DispatchCampaignJob.enqueue_deliveries(it) }
      Sidekiq.logger.warn("[Newsletter] re-enqueued #{ids.size} stuck deliveries")
    end
  end
end
