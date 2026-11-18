class PostsController < ApplicationController
  allow_unauthenticated_access

  def index
    posts = policy_scope(Post).visible.recent.includes(:author, :category, :tags)
    if params[:category].present?
      @category = Category.find_by!(slug: params[:category])
      posts = posts.where(category: @category)
    end
    if params[:tag].present?
      @tag = Tag.find_by!(name: params[:tag])
      posts = posts.with_tag(@tag.name)
    end
    @posts = posts.page(params[:page])
    @categories = Category.alphabetical
  end

  def show
    @post = policy_scope(Post).includes(:author, :category, :tags).find_by!(slug: params[:slug])
    authorize @post
    @comments = @post.comments.visible.chronological.includes(user: { avatar_attachment: :blob })
    @comment = @post.comments.new
  end
end
