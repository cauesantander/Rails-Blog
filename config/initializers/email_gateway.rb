# Registers EmailGateway as an ActionMailer delivery method (:email_gateway).
# Done in to_prepare because EmailGateway lives in app/ and is reloaded in development.
Rails.application.config.to_prepare do
  ActionMailer::Base.add_delivery_method :email_gateway, EmailGateway::ActionMailerDelivery

  if Rails.env.production? && EmailGateway.provider_name != "resend"
    Rails.logger.warn("[EmailGateway] EMAIL_PROVIDER=#{EmailGateway.provider_name}: e-mails will NOT be sent")
  end
end
