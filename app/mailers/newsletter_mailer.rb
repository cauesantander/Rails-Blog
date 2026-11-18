# Renders one campaign e-mail. It is never delivered through ActionMailer: the
# Newsletter::DeliverySender builds the Mail::Message with this mailer and hands it to
# EmailGateway itself, so it can control idempotency keys and error handling.
class NewsletterMailer < ApplicationMailer
  def campaign_email
    @delivery = params[:delivery]
    @campaign = @delivery.campaign
    @post = @campaign.post
    @unsubscribe_url = newsletter_unsubscribe_url(token: @delivery.subscriber.unsubscribe_token)

    # RFC 8058 one-click unsubscribe: Gmail/Yahoo show an "Unsubscribe" button and POST here.
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    headers["X-Campaign-Id"] = @campaign.id.to_s

    mail subject: @campaign.subject, to: @delivery.email
  end
end
