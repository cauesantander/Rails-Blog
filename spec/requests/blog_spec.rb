require "rails_helper"

RSpec.describe "Public blog" do
  let(:category) { create(:category, name: "Rails") }
  let!(:published) { create(:post, :published, title: "Publicado", category:, tag_list: "ruby") }
  let!(:draft) { create(:post, title: "Rascunho secreto") }
  let!(:future) { create(:post, :scheduled, title: "Do futuro") }

  it "lists only visible posts" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Publicado")
    expect(response.body).not_to include("Rascunho secreto", "Do futuro")
  end

  it "paginates (10 per page)" do
    create_list(:post, 11, :published)
    get posts_path
    expect(response.body.scan('class="card post-card"').size).to eq(10)
    get posts_path(page: 2)
    expect(response.body.scan('class="card post-card"').size).to eq(2)
  end

  it "filters by category and tag" do
    other = create(:post, :published, title: "Outro assunto")
    get category_path(category.slug)
    expect(response.body).to include("Publicado").and exclude(other.title)
    get tag_path("ruby")
    expect(response.body).to include("Publicado").and exclude(other.title)
  end

  it "shows a published post rendered from Markdown, escaping raw HTML" do
    published.update!(body: "**negrito** <script>alert(1)</script>")
    get post_path(published)
    expect(response.body).to include("<strong>negrito</strong>")
    expect(response.body).not_to include("<script>alert(1)</script>")
  end

  it "returns 404 for drafts and future posts to visitors and readers" do
    get post_path(draft)
    expect(response).to have_http_status(:not_found)
    sign_in_as(create(:user))
    get post_path(future)
    expect(response).to have_http_status(:not_found)
  end

  it "lets admins preview drafts" do
    sign_in_as(create(:user, :admin))
    get post_path(draft)
    expect(response).to have_http_status(:ok)
  end

  it "shows only visible comments" do
    create(:comment, post: published, body: "Comentário ok")
    create(:comment, post: published, body: "Comentário moderado", status: :hidden)
    get post_path(published)
    expect(response.body).to include("Comentário ok").and exclude("Comentário moderado")
  end
end

RSpec.describe "Comments" do
  let(:blog_post) { create(:post, :published) }
  let(:user) { create(:user) }

  it "requires login to comment" do
    post post_comments_path(blog_post), params: { comment: { body: "Oi" } }
    expect(response).to redirect_to(new_session_path)
    expect(Comment.count).to eq(0)
  end

  it "lets logged users comment" do
    sign_in_as(user)
    expect {
      post post_comments_path(blog_post), params: { comment: { body: "Excelente!" } }
    }.to change(blog_post.comments, :count).by(1)
    expect(Comment.last.user).to eq(user)
  end

  it "rejects empty comments" do
    sign_in_as(user)
    expect { post post_comments_path(blog_post), params: { comment: { body: "" } } }.not_to change(Comment, :count)
  end

  it "does not accept comments on drafts" do
    sign_in_as(user)
    post post_comments_path(create(:post)), params: { comment: { body: "x" } }
    expect(response).to have_http_status(:not_found)
  end

  it "lets the author delete their comment but not someone else's" do
    comment = create(:comment, post: blog_post, user:)
    others = create(:comment, post: blog_post)
    sign_in_as(user)

    delete post_comment_path(blog_post, others)
    expect(Comment.exists?(others.id)).to be(true)

    delete post_comment_path(blog_post, comment)
    expect(Comment.exists?(comment.id)).to be(false)
  end
end
