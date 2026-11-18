require "rails_helper"

RSpec.describe "Admin management" do
  let(:admin) { create(:user, :admin) }

  before { sign_in_as(admin) }

  describe "posts" do
    let(:category) { create(:category) }

    it "creates a draft post with tags" do
      expect {
        post admin_posts_path, params: { post: { title: "Novo post", body: "Texto", category_id: category.id,
                                                 tag_list: "ruby, rails", status: "draft" } }
      }.to change(Post, :count).by(1)

      created = Post.last
      expect(response).to redirect_to(admin_post_path(created))
      expect(created.attributes.slice("slug", "status")).to eq("slug" => "novo-post", "status" => "draft")
      expect(created.author).to eq(admin)
      expect(created.tag_list).to eq("ruby, rails")
    end

    it "re-renders the form on validation errors" do
      post admin_posts_path, params: { post: { title: "", body: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "updates, publishes, unpublishes and deletes" do
      blog_post = create(:post)

      patch admin_post_path(blog_post), params: { post: { title: "Título novo" } }
      expect(blog_post.reload.title).to eq("Título novo")

      post publish_admin_post_path(blog_post)
      expect(blog_post.reload).to be_visible

      post unpublish_admin_post_path(blog_post)
      expect(blog_post.reload).to be_draft

      delete admin_post_path(blog_post)
      expect(Post.exists?(blog_post.id)).to be(false)
    end
  end

  describe "categories" do
    it "creates, renames and deletes" do
      post admin_categories_path, params: { category: { name: "DevOps" } }
      category = Category.find_by!(name: "DevOps")

      patch admin_category_path(category), params: { category: { name: "Infra" } }
      expect(category.reload.slug).to eq("infra")

      delete admin_category_path(category)
      expect(Category.count).to eq(0)
    end
  end

  describe "comment moderation" do
    let(:comment) { create(:comment) }

    it "hides, restores and deletes comments" do
      patch admin_comment_path(comment), params: { status: "hidden" }
      expect(comment.reload).to be_hidden
      expect(comment.moderated_by).to eq(admin)

      patch admin_comment_path(comment), params: { status: "visible" }
      expect(comment.reload).to be_visible

      delete admin_comment_path(comment)
      expect(Comment.exists?(comment.id)).to be(false)
    end
  end

  describe "subscribers" do
    it "filters, unsubscribes and deletes" do
      subscriber = create(:subscriber, :confirmed, email: "ana@example.com")
      create(:subscriber, email: "bob@example.com")

      get admin_subscribers_path(status: "confirmed", q: "ana")
      expect(response.body).to include("ana@example.com").and exclude("bob@example.com")

      patch admin_subscriber_path(subscriber), params: { status: "unsubscribed" }
      expect(subscriber.reload).to be_unsubscribed

      delete admin_subscriber_path(subscriber)
      expect(Subscriber.exists?(subscriber.id)).to be(false)
    end
  end

  describe "campaigns" do
    let(:blog_post) { create(:post, :published) }

    it "creates a draft campaign linked to a post" do
      post admin_campaigns_path, params: { campaign: { subject: "Novidades", intro: "Oi", post_id: blog_post.id } }
      campaign = Campaign.last
      expect(campaign).to be_draft
      expect(campaign.post).to eq(blog_post)
      expect(campaign.created_by).to eq(admin)
    end

    it "'send now' queues the campaign and enqueues the dispatch job" do
      campaign = create(:campaign, post: blog_post)
      post schedule_admin_campaign_path(campaign)

      expect(campaign.reload).to be_queued
      expect(Newsletter::DispatchCampaignJob.jobs.map { it["args"] }).to eq([[campaign.id]])
    end

    it "schedules for later without enqueuing yet" do
      campaign = create(:campaign)
      post schedule_admin_campaign_path(campaign), params: { scheduled_at: 2.days.from_now.strftime("%Y-%m-%dT%H:%M") }

      expect(campaign.reload).to be_scheduled
      expect(Newsletter::DispatchCampaignJob.jobs).to be_empty
    end

    it "refuses to send a campaign whose post is a draft" do
      campaign = create(:campaign, post: create(:post))
      post schedule_admin_campaign_path(campaign)
      expect(campaign.reload).to be_draft
      expect(flash[:alert]).to include("publicado")
    end

    it "does not allow editing campaigns that were already sent" do
      campaign = create(:campaign, status: :sent)
      patch admin_campaign_path(campaign), params: { campaign: { subject: "Mudou" } }
      expect(campaign.reload.subject).not_to eq("Mudou")
    end

    it "shows delivery history with statuses and errors" do
      campaign = create(:campaign, :sending)
      create(:campaign_delivery, campaign:, status: :failed, last_error: "PermanentError: bounce")
      get admin_campaign_path(campaign)
      expect(response.body).to include("PermanentError: bounce")
    end

    it "re-enqueues failed deliveries" do
      campaign = create(:campaign, status: :sent, failed_count: 1)
      failed = create(:campaign_delivery, campaign:, status: :failed)
      post retry_failed_admin_campaign_path(campaign)
      expect(failed.reload).to be_pending
      expect(Newsletter::DeliverEmailJob.jobs.size).to eq(1)
    end

    it "unschedules and cancels" do
      campaign = create(:campaign, :scheduled, scheduled_at: 1.day.from_now)
      post unschedule_admin_campaign_path(campaign)
      expect(campaign.reload).to be_draft
      post cancel_admin_campaign_path(campaign)
      expect(campaign.reload).to be_canceled
    end
  end

  describe "users" do
    it "promotes and demotes other users but not itself" do
      reader = create(:user)
      patch admin_user_path(reader), params: { role: "admin" }
      expect(reader.reload).to be_admin

      patch admin_user_path(admin), params: { role: "reader" }
      expect(admin.reload).to be_admin
    end
  end

  it "dashboard shows queue information" do
    get admin_root_path
    expect(response.body).to include("Filas (Sidekiq)")
  end
end
