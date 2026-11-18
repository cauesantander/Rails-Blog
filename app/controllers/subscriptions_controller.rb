class SubscriptionsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_back_or_to root_path, alert: "Muitas tentativas. Tente novamente mais tarde." }

  def create
    subscriber = Subscriber.subscribe(params[:email], user: Current.user)

    if subscriber.errors.any?
      redirect_back_or_to root_path, alert: "E-mail inválido: #{subscriber.errors.full_messages.to_sentence}"
    else
      redirect_back_or_to root_path, notice: "Quase lá! Se este e-mail ainda não estiver inscrito, enviamos um link de confirmação."
    end
  end

  def confirm
    subscriber = Subscriber.find_by_token_for(:confirmation, params[:token])

    if subscriber
      subscriber.confirm!
      redirect_to root_path, notice: "Inscrição confirmada! Você receberá nossas próximas newsletters."
    else
      redirect_to root_path, alert: "Link de confirmação inválido ou expirado."
    end
  end
end
