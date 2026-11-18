require "net/http"

module EmailGateway
  # Real provider: https://resend.com/docs/api-reference/emails/send-email
  #
  # Uses Net::HTTP (stdlib) instead of an SDK: one endpoint, full control over timeouts
  # and over how each failure maps to our error taxonomy.
  class ResendAdapter
    ENDPOINT = URI("https://api.resend.com/emails")

    NETWORK_ERRORS = [
      SocketError, EOFError, IOError, OpenSSL::SSL::SSLError,
      Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::EPIPE
    ].freeze
    TIMEOUT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout].freeze

    def initialize(api_key:, open_timeout: ENV.fetch("EMAIL_OPEN_TIMEOUT", 5).to_f,
                   read_timeout: ENV.fetch("EMAIL_READ_TIMEOUT", 10).to_f, logger: Rails.logger)
      raise ConfigurationError, "RESEND_API_KEY is not set" if api_key.blank?

      @api_key = api_key
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @logger = logger
    end

    def deliver(message)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = post(message)
      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      @logger.info("[EmailGateway::Resend] status=#{response.code} duration_ms=#{elapsed_ms} " \
                   "idempotency_key=#{message.idempotency_key.inspect}")
      handle(response)
    rescue *TIMEOUT_ERRORS => e
      raise RetryableError, "Resend timeout (#{e.class})"
    rescue *NETWORK_ERRORS => e
      raise RetryableError, "Resend unavailable (#{e.class}: #{e.message})"
    end

    private
      def post(message)
        request = Net::HTTP::Post.new(ENDPOINT)
        request["Authorization"] = "Bearer #{@api_key}"
        request["Content-Type"] = "application/json"
        request["User-Agent"] = "rails-blog/1.0"
        # Resend keeps the key for 24h: the same key + same payload returns the original response
        # instead of sending the e-mail again.
        request["Idempotency-Key"] = message.idempotency_key if message.idempotency_key
        request.body = JSON.generate(payload(message))

        Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true,
                        open_timeout: @open_timeout, read_timeout: @read_timeout, write_timeout: @read_timeout) do |http|
          http.request(request)
        end
      end

      def payload(message)
        {
          from: message.from,
          to: message.to,
          subject: message.subject,
          html: message.html,
          text: message.text,
          headers: message.headers.presence
        }.compact
      end

      def handle(response)
        status = response.code.to_i
        body = parse(response.body)
        detail = "Resend HTTP #{status}: #{body['message'] || body['name'] || response.message}"

        case status
        when 200..299
          Result.new(message_id: body.fetch("id"))
        when 429
          raise RateLimitedError.new(detail, status:, retry_after: response["retry-after"]&.to_i)
        when 401, 403
          raise AuthenticationError.new(detail, status:)
        when 408, 409, 500..599
          raise RetryableError.new(detail, status:)
        else
          raise PermanentError.new(detail, status:)
        end
      end

      def parse(body)
        JSON.parse(body.to_s)
      rescue JSON::ParserError
        {}
      end
  end
end
