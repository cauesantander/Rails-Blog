# Redis connection shared by the Sidekiq server (worker process) and client (Rails app
# enqueuing jobs). Database 0 holds the queues; the cache uses database 1 in production.
SIDEKIQ_REDIS = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }.freeze

Sidekiq.configure_server do |config|
  config.redis = SIDEKIQ_REDIS

  # Error registry: every failed attempt is logged with job context (retries included).
  config.error_handlers << lambda do |exception, context, _config|
    job = context[:job] || {}
    Sidekiq.logger.error(
      "[Sidekiq] job_failed class=#{job['class']} jid=#{job['jid']} args=#{job['args'].inspect} " \
      "retry_count=#{job['retry_count'].inspect} error=#{exception.class}: #{exception.message}"
    )
  end
end

Sidekiq.configure_client do |config|
  config.redis = SIDEKIQ_REDIS
end

Sidekiq::Cron.configure do |config|
  config.cron_schedule_file = "config/schedule.yml"
end
