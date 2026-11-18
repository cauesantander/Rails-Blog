module EmailGateway
  # Development adapter: nothing leaves the machine. Each e-mail is logged and its HTML
  # is written to tmp/mails/ so it can be opened in a browser.
  #
  # EMAIL_LOG_FAILURE_RATE=0.3 makes ~30% of the calls raise a RetryableError, which is
  # handy to watch Sidekiq retries in the dashboard without a real provider.
  class LogAdapter
    def initialize(logger: Rails.logger, dir: Rails.root.join("tmp/mails"),
                   failure_rate: ENV.fetch("EMAIL_LOG_FAILURE_RATE", 0).to_f)
      @logger = logger
      @dir = dir
      @failure_rate = failure_rate
    end

    def deliver(message)
      if @failure_rate.positive? && rand < @failure_rate
        raise RetryableError, "simulated provider failure (EMAIL_LOG_FAILURE_RATE=#{@failure_rate})"
      end

      id = "log-#{SecureRandom.uuid}"
      FileUtils.mkdir_p(@dir)
      File.write(@dir.join("#{id}.html"), message.html || "<pre>#{ERB::Util.h(message.text)}</pre>")
      @logger.info("[EmailGateway::Log] id=#{id} to=#{message.to.join(',')} subject=#{message.subject.inspect} " \
                   "idempotency_key=#{message.idempotency_key.inspect} file=tmp/mails/#{id}.html")
      Result.new(message_id: id)
    end
  end
end
