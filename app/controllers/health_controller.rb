# Readiness check: unlike Rails' /up (the process is alive), /health verifies the
# dependencies the app needs to work: PostgreSQL and Redis (Sidekiq).
class HealthController < ActionController::API
  def show
    checks = {
      database: check { ActiveRecord::Base.connection.select_value("SELECT 1") == 1 },
      redis: check { Sidekiq.redis { it.call("PING") } == "PONG" }
    }
    healthy = checks.values.all?
    render json: { status: healthy ? "ok" : "degraded", checks: }, status: healthy ? :ok : :service_unavailable
  end

  private
    def check
      yield
    rescue StandardError => e
      Rails.logger.error("[Health] #{e.class}: #{e.message}")
      false
    end
end
