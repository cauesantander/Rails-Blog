class SubscriptionMailer < ApplicationMailer
  def confirmation
    @subscriber = params[:subscriber]
    @confirmation_url = newsletter_confirmation_url(token: @subscriber.generate_token_for(:confirmation))
    mail subject: "Confirme sua inscrição na newsletter", to: @subscriber.email
  end
end
