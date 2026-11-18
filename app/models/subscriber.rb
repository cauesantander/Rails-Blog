class Subscriber < ApplicationRecord
  belongs_to :user, optional: true
  has_many :campaign_deliveries, dependent: :nullify

  # Double opt-in: pending -> confirmed -> unsubscribed (-> pending again on re-subscribe).
  enum :status, { pending: "pending", confirmed: "confirmed", unsubscribed: "unsubscribed" },
       default: :pending, validate: true

  # Long-lived random token for the unsubscribe link (must keep working forever).
  has_secure_token :unsubscribe_token

  # Signed, expiring token for the confirmation link. Embedding confirmed_at makes the
  # token single-use: once confirmed_at changes, older tokens stop verifying.
  generates_token_for :confirmation, expires_in: 3.days do
    confirmed_at
  end

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: true, length: { maximum: 254 },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  # Creates or reactivates a subscription and sends the confirmation e-mail.
  # Always returns the subscriber so the controller can answer the same way whether
  # the address was new or not (avoids leaking who is subscribed).
  def self.subscribe(email, user: nil)
    subscriber = find_or_initialize_by(email: email.to_s.strip.downcase)
    return subscriber if subscriber.confirmed?

    subscriber.user ||= user
    subscriber.status = :pending
    SubscriptionMailer.with(subscriber:).confirmation.deliver_later if subscriber.save
    subscriber
  rescue ActiveRecord::RecordNotUnique
    # Two concurrent requests for the same e-mail: the unique index wins, reuse that row.
    retry
  end

  def confirm!
    update!(status: :confirmed, confirmed_at: Time.current, unsubscribed_at: nil)
  end

  def unsubscribe!
    return if unsubscribed?

    update!(status: :unsubscribed, unsubscribed_at: Time.current)
  end
end
