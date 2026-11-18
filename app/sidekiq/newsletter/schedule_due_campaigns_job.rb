module Newsletter
  # Periodic job (sidekiq-cron, every minute - see config/schedule.yml).
  #
  # - Moves campaigns whose scheduled_at has passed from "scheduled" to "queued" and
  #   enqueues their dispatch. The conditional UPDATE in Campaign#enqueue_dispatch! makes it
  #   safe if two schedulers run at the same time.
  # - Re-enqueues "queued" campaigns whose dispatch job never ran (lost job), which is
  #   harmless thanks to the dispatcher's idempotency.
  class ScheduleDueCampaignsJob
    include Sidekiq::Job
    sidekiq_options queue: :newsletter_dispatch, retry: false # the next cron tick is the retry

    def perform
      enqueued = Campaign.due.find_each.count(&:enqueue_dispatch!)

      recovered = 0
      Campaign.stale_queued.find_each do |campaign|
        campaign.update_columns(queued_at: Time.current)
        DispatchCampaignJob.perform_async(campaign.id)
        recovered += 1
      end

      Sidekiq.logger.info("[Newsletter] scheduler enqueued=#{enqueued} recovered=#{recovered}") if (enqueued + recovered).positive?
    end
  end
end
