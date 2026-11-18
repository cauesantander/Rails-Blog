# Boundary between the application and the e-mail provider.
#
# The rest of the app only knows EmailGateway.deliver(message) and the error classes
# below. Which adapter answers that call is configuration (EMAIL_PROVIDER):
#
#   resend -> ResendAdapter: real HTTP calls to https://resend.com
#   log    -> LogAdapter:    writes to the log and tmp/mails (development default)
#   test   -> TestAdapter:   in-memory, used by the test suite
#
# Error taxonomy (drives the retry policy of the jobs):
#
#   Error
#   ├── RetryableError        temporary: timeout, network, HTTP 5xx/408/409 -> retry later
#   │   ├── RateLimitedError  HTTP 429, carries retry_after                   -> retry after the hint
#   │   └── AuthenticationError  HTTP 401/403: bad/missing API key            -> retry (ops can fix it)
#   └── PermanentError        HTTP 4xx validation (invalid address...)        -> do not retry
module EmailGateway
  class Error < StandardError
    attr_reader :status

    def initialize(message = nil, status: nil)
      super(message)
      @status = status
    end
  end

  class RetryableError < Error; end
  class AuthenticationError < RetryableError; end
  class PermanentError < Error; end

  class RateLimitedError < RetryableError
    attr_reader :retry_after

    def initialize(message = nil, retry_after: nil, **)
      super(message, **)
      @retry_after = retry_after
    end
  end

  class ConfigurationError < StandardError; end

  ADAPTERS = {
    "resend" => -> { ResendAdapter.new(api_key: ENV["RESEND_API_KEY"]) },
    "log" => -> { LogAdapter.new },
    "test" => -> { TestAdapter.new }
  }.freeze

  class << self
    attr_writer :adapter

    def adapter
      @adapter ||= build(provider_name)
    end

    def deliver(message)
      adapter.deliver(message)
    end

    def provider_name
      ENV.fetch("EMAIL_PROVIDER") { Rails.env.test? ? "test" : "log" }
    end

    def build(name)
      factory = ADAPTERS.fetch(name) { raise ConfigurationError, "unknown EMAIL_PROVIDER=#{name.inspect}" }
      factory.call
    end
  end
end
