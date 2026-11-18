class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Muitas tentativas. Tente novamente mais tarde." }

  def new
    return redirect_to root_path if authenticated?

    @user = User.new
  end

  def create
    # role is never permitted here: everybody signs up as a reader.
    @user = User.new(params.expect(user: [ :name, :email_address, :password, :password_confirmation ]))

    if @user.save
      start_new_session_for @user
      redirect_to root_path, notice: "Conta criada com sucesso. Bem-vindo(a), #{@user.name}!"
    else
      render :new, status: :unprocessable_content
    end
  end
end
