module Admin
  class PostsController < BaseController
    before_action :set_post, only: %i[show edit update destroy publish unpublish]

    def index
      authorize Post
      @posts = Post.includes(:author, :category).order(created_at: :desc).page(params[:page])
      @posts = @posts.where(status: params[:status]) if Post.statuses.key?(params[:status])
    end

    def show
    end

    def new
      @post = authorize Post.new
    end

    def create
      @post = authorize Post.new(post_params.merge(author: Current.user))

      if @post.save
        redirect_to admin_post_path(@post), notice: "Post criado."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @post.update(post_params)
        redirect_to admin_post_path(@post), notice: "Post atualizado."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @post.destroy!
      redirect_to admin_posts_path, status: :see_other, notice: "Post excluído."
    end

    def publish
      @post.publish!
      redirect_back_or_to admin_post_path(@post), notice: "Post publicado."
    end

    def unpublish
      @post.unpublish!
      redirect_back_or_to admin_post_path(@post), notice: "Post despublicado."
    end

    private
      def set_post
        @post = authorize Post.find_by!(slug: params[:slug])
      end

      def post_params
        params.expect(post: [ :title, :slug, :excerpt, :body, :category_id, :tag_list, :status, :published_at ])
      end
  end
end
