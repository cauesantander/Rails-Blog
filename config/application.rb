require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RailsBlog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Brasilia"
    config.i18n.default_locale = :"pt-BR"
    config.i18n.available_locales = [:"pt-BR", :en]

    # Every Active Job (including ActionMailer#deliver_later) runs on Sidekiq/Redis.
    config.active_job.queue_adapter = :sidekiq
    config.action_mailer.deliver_later_queue_name = :mailers
    config.action_mailer.delivery_job = "TransactionalMailDeliveryJob"
    # Without this, delivery errors would be swallowed and the job could never retry.
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.default_url_options = {
      host: ENV.fetch("APP_HOST", "localhost"),
      port: ENV["APP_PORT"].presence,
      protocol: ENV.fetch("APP_PROTOCOL", "http")
    }.compact

    # Newsletter fan-out tuning (see Newsletter::CampaignDispatcher).
    config.x.newsletter.batch_size = ENV.fetch("NEWSLETTER_BATCH_SIZE", 100).to_i
    config.x.newsletter.batch_interval = ENV.fetch("NEWSLETTER_BATCH_INTERVAL_SECONDS", 30).to_i.seconds

    # Active Storage service: "local" (disk) by default, "amazon" to use S3 (config/storage.yml).
    config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "local").to_sym

    config.generators do |g|
      g.test_framework :rspec
      g.system_tests = nil
    end
  end
end
