# Active Job used by every `deliver_later` (config.action_mailer.delivery_job).
# Transactional e-mails go through Active Job (Rails' standard path) running on the
# Sidekiq adapter; retries are declared here with retry_on/discard_on.
class TransactionalMailDeliveryJob < ActionMailer::MailDeliveryJob
  queue_as :mailers

  # Retries are handled by Active Job; when they run out the error bubbles up and
  # retry: 0 sends the job straight to Sidekiq's Dead set (visible in /admin/sidekiq)
  # instead of starting a second, independent retry cycle in Sidekiq.
  sidekiq_options retry: 0

  retry_on EmailGateway::RetryableError, wait: :polynomially_longer, attempts: 5
  discard_on EmailGateway::PermanentError do |job, error|
    Rails.logger.error("[TransactionalMail] discarded job_id=#{job.job_id} error=#{error.message}")
  end
end
