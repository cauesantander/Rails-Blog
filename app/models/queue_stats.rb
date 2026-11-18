# Read-only snapshot of Sidekiq's state for the admin dashboard (the full picture lives
# in the Sidekiq Web UI at /admin/sidekiq). Never raises: Redis being down is itself
# useful information for the dashboard.
class QueueStats
  Snapshot = Data.define(:available, :processed, :failed, :enqueued, :scheduled, :retries, :dead, :queues, :processes, :error)

  def self.snapshot
    stats = Sidekiq::Stats.new
    Snapshot.new(
      available: true,
      processed: stats.processed,
      failed: stats.failed,
      enqueued: stats.enqueued,
      scheduled: stats.scheduled_size,
      retries: stats.retry_size,
      dead: stats.dead_size,
      queues: Sidekiq::Queue.all.map { { name: it.name, size: it.size, latency: it.latency.round(1) } },
      processes: Sidekiq::ProcessSet.new.size,
      error: nil
    )
  rescue StandardError => e
    Snapshot.new(available: false, processed: 0, failed: 0, enqueued: 0, scheduled: 0, retries: 0, dead: 0,
                 queues: [], processes: 0, error: "#{e.class}: #{e.message}")
  end
end
