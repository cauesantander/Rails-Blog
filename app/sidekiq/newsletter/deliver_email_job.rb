module Newsletter
  # Step 2 of a campaign send: one job per recipient, so each e-mail has its own retry cycle.
  #
  # Retry policy:
  # - RetryableError / unexpected errors -> raised by DeliverySender, Sidekiq retries with
  #   exponential backoff + jitter (MAX_RETRIES = 10 -> retries spread over ~4-5 hours);
  # - RateLimitedError -> waits what the provider asked for (Retry-After) plus jitter;
  # - when retries run out -> sidekiq_retries_exhausted marks the delivery as failed and
  #   the job goes to the Dead set, where it can be inspected in /admin/sidekiq.
  class DeliverEmailJob
    include Sidekiq::Job

    MAX_RETRIES = 10

    sidekiq_options queue: :newsletter_delivery, retry: MAX_RETRIES

    sidekiq_retry_in do |count, exception, _job|
      if exception.is_a?(EmailGateway::RateLimitedError) && exception.retry_after.to_i.positive?
        exception.retry_after + rand(5)
      else
        (count**4) + 15 + (rand(10) * (count + 1)) # same curve as Sidekiq's default
      end
    end

    sidekiq_retries_exhausted do |job, exception|
      delivery = CampaignDelivery.find_by(id: job["args"].first)
      next unless delivery

      delivery.mark_failed!(exception)
      delivery.campaign.finalize_if_complete!
      Sidekiq.logger.error("[Newsletter] delivery failed after retries delivery_id=#{delivery.id} " \
                           "error=#{exception.class}: #{exception.message}")
    end

    def perform(delivery_id)
      delivery = CampaignDelivery.find_by(id: delivery_id)
      return Sidekiq.logger.warn("[Newsletter] delivery #{delivery_id} not found") unless delivery

      DeliverySender.call(delivery)
    end
  end
end
