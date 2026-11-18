module EmailGateway
  # In-memory adapter for the test suite. Records deliveries, honours idempotency keys
  # like a real provider would, and can be told to fail the next N calls.
  class TestAdapter
    attr_reader :deliveries

    def initialize
      reset!
    end

    def reset!
      @deliveries = []
      @failures = []
      @seen_keys = {}
    end

    # adapter.fail_next(EmailGateway::RetryableError.new("boom"), times: 2)
    def fail_next(error, times: 1)
      @failures.concat([error] * times)
    end

    def deliver(message)
      raise @failures.shift if @failures.any?

      if message.idempotency_key && @seen_keys.key?(message.idempotency_key)
        return @seen_keys[message.idempotency_key]
      end

      @deliveries << message
      Result.new(message_id: "test-#{@deliveries.size}").tap do |result|
        @seen_keys[message.idempotency_key] = result if message.idempotency_key
      end
    end
  end
end
