module Admin
  class CommentsController < BaseController
    before_action :set_comment, only: %i[update destroy]

    def index
      @comments = Comment.includes(:user, :post).order(created_at: :desc).page(params[:page])
      @comments = @comments.where(status: params[:status]) if Comment.statuses.key?(params[:status])
    end

    # PATCH /admin/comments/:id with status=hidden|visible
    def update
      authorize @comment, :moderate?
      case params[:status]
      when "hidden" then @comment.hide!(by: Current.user)
      when "visible" then @comment.restore!(by: Current.user)
      else return redirect_back_or_to(admin_comments_path, alert: "Status inválido.")
      end
      redirect_back_or_to admin_comments_path, notice: "Comentário #{@comment.hidden? ? 'ocultado' : 'restaurado'}."
    end

    def destroy
      authorize @comment
      @comment.destroy!
      redirect_back_or_to admin_comments_path, status: :see_other, notice: "Comentário excluído."
    end

    private
      def set_comment
        @comment = Comment.find(params[:id])
      end
  end
end
