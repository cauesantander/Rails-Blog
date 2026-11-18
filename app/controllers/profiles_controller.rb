class ProfilesController < ApplicationController
  before_action :set_user

  def show
  end

  def edit
  end

  def update
    attributes = profile_params
    if attributes[:password].blank?
      attributes = attributes.except(:password, :password_confirmation, :password_challenge)
    end
    @user.avatar.purge_later if params.dig(:user, :remove_avatar) == "1" && attributes[:avatar].blank?

    if @user.update(attributes)
      redirect_to profile_path, notice: "Perfil atualizado."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_user
      @user = Current.user
    end

    # password_challenge (Rails 7.1+): has_secure_password checks it against the current
    # password, so changing the password requires knowing the old one.
    def profile_params
      params.expect(user: [ :name, :bio, :avatar, :password, :password_confirmation, :password_challenge ])
    end
end
