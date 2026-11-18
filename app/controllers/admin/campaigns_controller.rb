module Admin
  class CampaignsController < BaseController
    before_action :set_campaign, except: %i[index new create]
    before_action :require_editable, only: %i[edit update destroy]

    rescue_from Campaign::InvalidTransition do |error|
      redirect_to admin_campaign_path(@campaign), alert: "Operação não permitida: #{error.message}"
    end

    def index
      @campaigns = Campaign.recent.includes(:post, :created_by).page(params[:page])
    end

    def show
      @deliveries = @campaign.deliveries.order(:id).page(params[:page]).per(50)
      @deliveries = @deliveries.where(status: params[:status]) if CampaignDelivery.statuses.key?(params[:status])
      @delivery_counts = @campaign.deliveries.group(:status).count
    end

    def new
      post = Post.visible.find_by(id: params[:post_id])
      @campaign = Campaign.new(post:, subject: post&.title)
    end

    def create
      @campaign = Campaign.new(campaign_params.merge(created_by: Current.user))

      if @campaign.save
        redirect_to admin_campaign_path(@campaign), notice: "Campanha criada como rascunho."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @campaign.update(campaign_params)
        redirect_to admin_campaign_path(@campaign), notice: "Campanha atualizada."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @campaign.destroy!
      redirect_to admin_campaigns_path, status: :see_other, notice: "Campanha excluída."
    end

    # POST /admin/campaigns/:id/schedule  (scheduled_at blank = send now)
    def schedule
      at = parse_time(params[:scheduled_at]) || Time.current
      @campaign.schedule!(at:)
      if at <= Time.current && @campaign.enqueue_dispatch!
        redirect_to admin_campaign_path(@campaign), notice: "Envio iniciado. Acompanhe o progresso abaixo."
      else
        redirect_to admin_campaign_path(@campaign), notice: "Campanha agendada para #{I18n.l(at, format: :short)}."
      end
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_campaign_path(@campaign), alert: e.record.errors.full_messages.to_sentence
    end

    def unschedule
      @campaign.unschedule!
      redirect_to admin_campaign_path(@campaign), notice: "Agendamento removido; campanha voltou a rascunho."
    end

    def cancel
      @campaign.cancel!
      redirect_to admin_campaign_path(@campaign), notice: "Campanha cancelada."
    end

    def retry_failed
      count = @campaign.retry_failed_deliveries!
      redirect_to admin_campaign_path(@campaign), notice: "#{count} envio(s) com falha reenfileirado(s)."
    end

    private
      def set_campaign
        @campaign = Campaign.find(params[:id])
      end

      def require_editable
        redirect_to admin_campaign_path(@campaign), alert: "Campanhas já enviadas não podem ser alteradas." unless @campaign.editable?
      end

      def campaign_params
        params.expect(campaign: [ :subject, :intro, :post_id ])
      end

      def parse_time(value)
        Time.zone.parse(value) if value.present?
      end
  end
end
