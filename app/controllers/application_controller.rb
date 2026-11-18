class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private
    def pundit_user = Current.user

    def forbidden
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Você não tem permissão para acessar esta página." }
        format.any { head :forbidden }
      end
    end

    def not_found
      respond_to do |format|
        format.html { render file: Rails.public_path.join("404.html"), status: :not_found, layout: false }
        format.any { head :not_found }
      end
    end
end
