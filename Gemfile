source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Redis client used by the production cache store (Sidekiq uses redis-client internally)
gem "redis", ">= 5.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Background jobs (Redis-backed) + periodic jobs (cron) [https://github.com/sidekiq/sidekiq]
gem "sidekiq", "~> 8.0"
gem "sidekiq-cron", "~> 2.0"

# Authorization policies [https://github.com/varvet/pundit]
gem "pundit", "~> 2.4"

# pt-BR translations for Rails (validation messages, dates) [https://github.com/svenfuchs/rails-i18n]
gem "rails-i18n", "~> 8.0"

# Pagination [https://github.com/kaminari/kaminari]
gem "kaminari", "~> 1.2"

# Markdown rendering for post bodies [https://github.com/vmg/redcarpet]
gem "redcarpet", "~> 3.6"

# Active Storage S3 service (only loaded when config/storage.yml uses :amazon)
gem "aws-sdk-s3", require: false

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "faker"
end

group :test do
  gem "shoulda-matchers", "~> 6.0"
  gem "webmock"
  gem "simplecov", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end
