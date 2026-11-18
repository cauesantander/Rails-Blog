module EmailGateway
  # ActionMailer delivery method (config.action_mailer.delivery_method = :email_gateway).
  # Makes transactional e-mails (password reset, subscription confirmation) use the same
  # provider integration as the newsletter, instead of a separate SMTP setup.
  class ActionMailerDelivery
    attr_accessor :settings

    def initialize(settings = {})
      @settings = settings
    end

    def deliver!(mail)
      result = EmailGateway.deliver(Message.from_mail(mail))
      mail.header["X-Provider-Message-Id"] = result.message_id
      result
    end
  end
end
