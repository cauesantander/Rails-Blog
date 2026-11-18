module Admin
  class UsersController < BaseController
    def index
      authorize User
      @users = User.order(:name).with_attached_avatar.page(params[:page]).per(25)
    end

    # PATCH /admin/users/:id with role=admin|reader
    def update
      user = User.find(params[:id])
      authorize user, :update_role?

      if user.update(role: params[:role])
        redirect_to admin_users_path, notice: "#{user.name} agora é #{user.admin? ? 'administrador' : 'leitor'}."
      else
        redirect_to admin_users_path, alert: user.errors.full_messages.to_sentence
      end
    end
  end
end
