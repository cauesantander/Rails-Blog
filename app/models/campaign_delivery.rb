# One e-mail of a campaign to one subscriber. This row is the unit of idempotency:
# it is created once (unique index on campaign_id + subscriber_id) and its status only
# moves forward through conditional UPDATEs, so duplicated or concurrent jobs cannot
# send the same e-mail twice.
#
#   pending --claim!--> sending --mark_sent!----> sent
#      ^                  |  \---mark_failed!--> failed   (permanent error / retries exhausted)
#      +----release!------+   \--mark_skipped!-> skipped  (subscriber left before we sent)
class CampaignDelivery < ApplicationRecord
  belongs_to :campaign
  belongs_to :subscriber, optional: true

  enum :status, { pending: "pending", sending: "sending", sent: "sent", failed: "failed", skipped: "skipped" },
       default: :pending, validate: true

  # A delivery stuck in "sending" for longer than this is considered abandoned
  # (worker crashed mid-request) and may be claimed again.
  LOCK_TIMEOUT = 15.minutes

  validates :email, presence: true

  scope :stale, ->(now = Time.current) { sending.where(locked_at: ...(now - LOCK_TIMEOUT)) }

  # Sent to the e-mail provider so that a retry after a crash (e-mail sent, row not yet
  # marked as sent) is deduplicated on the provider side as well.
  def idempotency_key = "campaign-delivery-#{id}"

  # pending -> sending. Returns true only for the caller that won the race.
  def claim!(now: Time.current)
    claimed = self.class
      .where(id:)
      .where("status = 'pending' OR (status = 'sending' AND locked_at < ?)", now - LOCK_TIMEOUT)
      .update_all(["status = 'sending', locked_at = ?, attempts = attempts + 1, updated_at = ?", now, now])
    reload if claimed == 1
    claimed == 1
  end

  def mark_sent!(provider_message_id)
    finish!(from: "sending", to: "sent", counter: :sent_count,
            sent_at: Time.current, provider_message_id:, last_error: nil)
  end

  def mark_failed!(error)
    finish!(from: %w[pending sending], to: "failed", counter: :failed_count,
            failed_at: Time.current, last_error: error_message(error))
  end

  def mark_skipped!(reason)
    finish!(from: "sending", to: "skipped", counter: nil, last_error: reason)
  end

  # sending -> pending after a retryable error; Sidekiq runs the job again later.
  def release!(error)
    self.class.where(id:, status: "sending")
        .update_all(status: "pending", locked_at: nil, last_error: error_message(error), updated_at: Time.current)
    reload
  end

  private
    def finish!(from:, to:, counter:, **attributes)
      transaction do
        updated = self.class.where(id:, status: from)
                      .update_all(status: to, locked_at: nil, updated_at: Time.current, **attributes)
        # The counter only moves for the call that performed the transition: never double counted.
        Campaign.update_counters(campaign_id, counter => 1) if updated == 1 && counter
        reload
        updated == 1
      end
    end

    def error_message(error)
      text = error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
      text.truncate(1_000)
    end
end
