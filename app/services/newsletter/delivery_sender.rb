module Newsletter
  # Sends a single CampaignDelivery. Can be called any number of times for the same row:
  #
  # 1. claim!   - atomic pending -> sending; losers (duplicate/concurrent jobs) stop here.
  # 2. render   - NewsletterMailer builds the Mail::Message.
  # 3. deliver  - EmailGateway with an idempotency key (covers "sent but crashed before step 4").
  # 4. mark     - sent / failed / skipped, and the campaign is finalized when nothing is left.
  #
  # Retryable errors put the row back to "pending" and are re-raised so that Sidekiq
  # schedules the retry. Permanent errors are recorded and swallowed: retrying won't help.
  class DeliverySender
    def self.call(delivery, **) = new(delivery, **).call

    def initialize(delivery, gateway: EmailGateway, logger: Rails.logger)
      @delivery = delivery
      @gateway = gateway
      @logger = logger
    end

    # Returns the final status of the delivery (or :not_claimed).
    def call
      unless @delivery.claim!
        log("not claimed (already processed or in flight)", status: @delivery.status)
        return :not_claimed
      end

      unless @delivery.subscriber&.confirmed?
        @delivery.mark_skipped!("subscriber is no longer confirmed")
        log("skipped")
        return finish(:skipped)
      end

      result = @gateway.deliver(build_message)
      @delivery.mark_sent!(result.message_id)
      log("sent", provider_message_id: result.message_id)
      finish(:sent)
    rescue EmailGateway::PermanentError => e
      @delivery.mark_failed!(e)
      log("failed permanently", error: e.message, level: :warn)
      finish(:failed)
    rescue StandardError => e
      # Retryable provider errors and unexpected bugs alike: release the row and let Sidekiq retry.
      @delivery.release!(e)
      log("will retry", error: "#{e.class}: #{e.message}", level: :warn)
      raise
    end

    private
      def build_message
        mail = NewsletterMailer.with(delivery: @delivery).campaign_email.message
        EmailGateway::Message.from_mail(mail, idempotency_key: @delivery.idempotency_key)
      end

      def finish(status)
        @delivery.campaign.finalize_if_complete!
        status
      end

      def log(event, level: :info, **data)
        details = { delivery_id: @delivery.id, campaign_id: @delivery.campaign_id, attempt: @delivery.attempts, **data }
        @logger.public_send(level, "[Newsletter] delivery #{event} #{details.map { |k, v| "#{k}=#{v}" }.join(' ')}")
      end
  end
end
