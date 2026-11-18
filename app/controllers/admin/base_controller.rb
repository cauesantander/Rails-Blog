module Admin
  # Every admin controller inherits from here: login is required (Authentication concern)
  # and the AdminPolicy must allow access, otherwise Pundit::NotAuthorizedError -> redirect.
  class BaseController < ApplicationController
    layout "admin"
    before_action :authorize_admin!

    private
      def authorize_admin!
        authorize :admin, :access?
      end
  end
end
