# A newsletter send. Lifecycle:
#
#   draft --schedule!--> scheduled --enqueue_dispatch!--> queued --(dispatcher)--> sending --> sent
#     ^                     |                                                         ^         |
#     +----unschedule!------+                                                         +---------+
#                                                                          retry_failed_deliveries!
#   draft/scheduled --cancel!--> canceled
#
# Transitions that can race (scheduler, workers, admin clicks) use conditional
# UPDATE ... WHERE status = ? statements, so exactly one caller wins each transition.
class Campaign < ApplicationRecord
  belongs_to :post, optional: true
  belongs_to :created_by, class_name: "User"
  has_many :deliveries, class_name: "CampaignDelivery", dependent: :delete_all

  enum :status, {
    draft: "draft", scheduled: "scheduled", queued: "queued",
    sending: "sending", sent: "sent", canceled: "canceled"
  }, default: :draft, validate: true

  # A queued campaign whose dispatch job did not run within this window is re-enqueued
  # (e.g. the job was lost because a worker was killed).
  STALE_QUEUE_AFTER = 10.minutes

  class InvalidTransition < StandardError; end

  validates :subject, presence: true, length: { maximum: 150 }
  validates :intro, length: { maximum: 5_000 }
  validates :scheduled_at, presence: true, if: :scheduled?
  validate :post_must_be_visible, if: -> { scheduled? && post.present? }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :due, ->(now = Time.current) { scheduled.where(scheduled_at: ..now) }
  scope :stale_queued, ->(now = Time.current) { queued.where(queued_at: ...(now - STALE_QUEUE_AFTER)) }

  def editable? = draft? || scheduled?

  def schedule!(at: Time.current)
    raise InvalidTransition, "only draft campaigns can be scheduled" unless draft?

    update!(status: :scheduled, scheduled_at: at)
  end

  def unschedule!
    transition!(from: :scheduled, to: :draft) || raise(InvalidTransition, "campaign is no longer scheduled")
  end

  def cancel!
    transition!(from: %i[draft scheduled], to: :canceled) || raise(InvalidTransition, "campaign already started")
  end

  # scheduled -> queued, then enqueue the dispatcher. Returns false if somebody else already did it.
  def enqueue_dispatch!
    claimed = transition!(from: :scheduled, to: :queued, queued_at: Time.current)
    Newsletter::DispatchCampaignJob.perform_async(id) if claimed
    claimed
  end

  # Called by the dispatcher once every recipient row exists.
  def mark_sending!(recipients_count:)
    self.class.where(id:, status: %w[queued sending])
        .update_all(status: "sending", recipients_count:, started_at: started_at || Time.current, updated_at: Time.current)
    reload
  end

  # sending -> sent when no delivery is pending or in flight. Safe to call from every worker:
  # the single conditional UPDATE below succeeds at most once.
  def finalize_if_complete!
    unfinished = CampaignDelivery.where(campaign_id: id, status: %w[pending sending])
    finished = self.class.where(id:, status: "sending").where.not(unfinished.arel.exists)
                   .update_all(status: "sent", finished_at: Time.current, updated_at: Time.current)
    reload if finished == 1
    finished == 1
  end

  # Admin action: give failed recipients another chance. Returns how many were re-enqueued.
  def retry_failed_deliveries!
    ids = transaction do
      lock!
      raise InvalidTransition, "campaign has not been sent yet" unless sent? || sending?

      failed_ids = deliveries.failed.pluck(:id)
      next [] if failed_ids.empty?

      deliveries.where(id: failed_ids)
                .update_all(status: "pending", failed_at: nil, locked_at: nil, updated_at: Time.current)
      update!(status: :sending, failed_count: failed_count - failed_ids.size, finished_at: nil)
      failed_ids
    end
    # Enqueue only after COMMIT, otherwise a fast worker could still read the old rows.
    Newsletter::DispatchCampaignJob.enqueue_deliveries(ids)
    ids.size
  end

  def skipped_count = deliveries.skipped.count

  def progress_percent
    return 0 if recipients_count.zero?

    ((sent_count + failed_count + skipped_count) * 100.0 / recipients_count).round
  end

  private
    def transition!(from:, to:, **attributes)
      updated = self.class.where(id:, status: Array(from).map(&:to_s))
                    .update_all(status: to.to_s, updated_at: Time.current, **attributes)
      reload if updated == 1
      updated == 1
    end

    def post_must_be_visible
      errors.add(:post, "precisa estar publicado para ser enviado") unless post.visible?
    end
end
