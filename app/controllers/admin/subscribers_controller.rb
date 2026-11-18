module Admin
  class SubscribersController < BaseController
    before_action :set_subscriber, only: %i[update destroy]

    def index
      @subscribers = Subscriber.order(created_at: :desc).page(params[:page]).per(25)
      @subscribers = @subscribers.where(status: params[:status]) if Subscriber.statuses.key?(params[:status])
      @subscribers = @subscribers.where("email ILIKE ?", "%#{Subscriber.sanitize_sql_like(params[:q])}%") if params[:q].present?
      @status_counts = Subscriber.group(:status).count
    end

    # PATCH /admin/subscribers/:id with status=unsubscribed|confirmed
    def update
      case params[:status]
      when "unsubscribed" then @subscriber.unsubscribe!
      when "confirmed" then @subscriber.confirm!
      else return redirect_back_or_to(admin_subscribers_path, alert: "Status inválido.")
      end
      redirect_back_or_to admin_subscribers_path, notice: "Inscrição de #{@subscriber.email} atualizada."
    end

    def destroy
      @subscriber.destroy!
      redirect_back_or_to admin_subscribers_path, status: :see_other, notice: "Inscrito removido."
    end

    private
      def set_subscriber
        @subscriber = Subscriber.find(params[:id])
      end
  end
end
