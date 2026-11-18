require "simplecov"
SimpleCov.start "rails" do
  add_group "Integrations", "app/integrations"
  add_group "Services", "app/services"
  add_group "Sidekiq jobs", "app/sidekiq"
  add_group "Policies", "app/policies"
end

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "sidekiq/testing"
require "webmock/rspec"

Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# No real HTTP from the test suite: external APIs are stubbed with WebMock.
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
  config.infer_spec_type_from_file_location!

  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActiveJob::TestHelper

  config.before do
    # Native Sidekiq jobs are pushed to an in-memory array (Sidekiq::Testing.fake!);
    # specs call .drain / perform_one to execute them explicitly.
    Sidekiq::Testing.fake!
    Sidekiq::Job.clear_all
    EmailGateway.adapter = EmailGateway::TestAdapter.new
    ActionMailer::Base.deliveries.clear
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
