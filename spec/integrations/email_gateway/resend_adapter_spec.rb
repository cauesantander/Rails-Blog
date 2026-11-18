require "rails_helper"

RSpec.describe EmailGateway::ResendAdapter do
  subject(:adapter) { described_class.new(api_key: "re_test_key", logger: Logger.new(nil)) }

  let(:endpoint) { "https://api.resend.com/emails" }
  let(:message) do
    EmailGateway::Message.new(
      to: "ana@example.com", from: "Blog <no-reply@example.com>", subject: "Olá",
      html: "<p>Oi</p>", text: "Oi", headers: { "List-Unsubscribe" => "<https://x/u>" },
      idempotency_key: "campaign-delivery-42"
    )
  end

  def stub_resend(status:, body: {}, headers: {})
    stub_request(:post, endpoint).to_return(status:, body: body.to_json, headers: { "Content-Type" => "application/json" }.merge(headers))
  end

  it "requires an API key" do
    expect { described_class.new(api_key: nil) }.to raise_error(EmailGateway::ConfigurationError)
  end

  it "posts the e-mail with auth and idempotency headers and returns the provider id" do
    stub_resend(status: 200, body: { id: "re_abc123" })

    result = adapter.deliver(message)

    expect(result).to eq(EmailGateway::Result.new(message_id: "re_abc123"))
    expect(WebMock).to have_requested(:post, endpoint).with(
      headers: { "Authorization" => "Bearer re_test_key", "Idempotency-Key" => "campaign-delivery-42" },
      body: hash_including("to" => ["ana@example.com"], "subject" => "Olá", "html" => "<p>Oi</p>",
                           "headers" => { "List-Unsubscribe" => "<https://x/u>" })
    )
  end

  it "maps HTTP 429 to RateLimitedError with the Retry-After hint" do
    stub_resend(status: 429, body: { name: "rate_limit_exceeded", message: "Too many requests" }, headers: { "Retry-After" => "7" })

    expect { adapter.deliver(message) }.to raise_error(EmailGateway::RateLimitedError) { |e|
      expect(e.retry_after).to eq(7)
      expect(e.status).to eq(429)
      expect(e).to be_a(EmailGateway::RetryableError)
    }
  end

  it "maps 5xx to RetryableError" do
    stub_resend(status: 503, body: { message: "unavailable" })
    expect { adapter.deliver(message) }.to raise_error(EmailGateway::RetryableError, /503/)
  end

  it "maps 401/403 to AuthenticationError (retryable: credentials can be fixed)" do
    stub_resend(status: 401, body: { message: "API key is invalid" })
    expect { adapter.deliver(message) }.to raise_error(EmailGateway::AuthenticationError, /API key is invalid/)
  end

  it "maps validation 4xx to PermanentError" do
    stub_resend(status: 422, body: { name: "validation_error", message: "Invalid `to` field" })
    expect { adapter.deliver(message) }.to raise_error(EmailGateway::PermanentError, /Invalid `to` field/)
  end

  it "maps timeouts to RetryableError" do
    stub_request(:post, endpoint).to_timeout
    expect { adapter.deliver(message) }.to raise_error(EmailGateway::RetryableError, /timeout/i)
  end

  it "maps connection failures to RetryableError" do
    stub_request(:post, endpoint).to_raise(Errno::ECONNREFUSED)
    expect { adapter.deliver(message) }.to raise_error(EmailGateway::RetryableError, /unavailable/)
  end

  it "survives non-JSON error bodies" do
    stub_request(:post, endpoint).to_return(status: 502, body: "<html>Bad gateway</html>")
    expect { adapter.deliver(message) }.to raise_error(EmailGateway::RetryableError, /502/)
  end
end
