# GET shows a confirmation button (link scanners/prefetchers only issue GETs, so they
# cannot unsubscribe anyone). POST performs it, and is also the RFC 8058 one-click
# endpoint that mail clients call without a CSRF token: the secret token authenticates it.
class UnsubscribesController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection only: :create
  before_action :set_subscriber

  def show
  end

  def create
    @subscriber.unsubscribe!
    respond_to do |format|
      format.html { redirect_to root_path, notice: "Inscrição cancelada. Você não receberá mais nossas newsletters." }
      format.any { head :ok }
    end
  end

  private
    def set_subscriber
      @subscriber = Subscriber.find_by!(unsubscribe_token: params[:token])
    end
end
