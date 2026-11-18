class CommentsController < ApplicationController
  before_action :set_post

  def create
    @comment = @post.comments.new(comment_params.merge(user: Current.user))
    authorize @comment

    if @comment.save
      redirect_to post_path(@post, anchor: "comment-#{@comment.id}"), notice: "Comentário publicado."
    else
      redirect_to post_path(@post, anchor: "new-comment"), alert: @comment.errors.full_messages.to_sentence
    end
  end

  def destroy
    @comment = @post.comments.find(params[:id])
    authorize @comment
    @comment.destroy!
    redirect_to post_path(@post), status: :see_other, notice: "Comentário removido."
  end

  private
    def set_post
      @post = Post.visible.find_by!(slug: params[:post_slug])
    end

    def comment_params
      params.expect(comment: [ :body ])
    end
end
