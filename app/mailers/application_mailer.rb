class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Rails Blog <no-reply@example.com>") }
  layout "mailer"
end
