require "rails_helper"

# Every admin route must be protected: visitors are sent to login, readers are refused.
RSpec.describe "Admin access control" do
  admin_get_paths = %w[/admin /admin/posts /admin/posts/new /admin/categories /admin/comments
                       /admin/subscribers /admin/campaigns /admin/campaigns/new /admin/users]

  admin_get_paths.each do |path|
    it "redirects visitors to login on GET #{path}" do
      get path
      expect(response).to redirect_to(new_session_path)
    end

    it "refuses readers on GET #{path}" do
      sign_in_as(create(:user))
      get path
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("permissão")
    end

    it "allows admins on GET #{path}" do
      sign_in_as(create(:user, :admin))
      get path
      expect(response).to have_http_status(:ok)
    end
  end

  it "refuses state-changing admin actions to readers" do
    blog_post = create(:post)
    campaign = create(:campaign)
    sign_in_as(create(:user))

    post publish_admin_post_path(blog_post)
    delete admin_post_path(blog_post)
    post schedule_admin_campaign_path(campaign)

    expect(blog_post.reload).to be_draft
    expect(campaign.reload).to be_draft
    expect(Newsletter::DispatchCampaignJob.jobs).to be_empty
  end

  it "answers 403 to non-HTML clients" do
    sign_in_as(create(:user))
    get admin_posts_path, headers: { "Accept" => "application/json" }
    expect(response).to have_http_status(:forbidden)
  end

  describe "Sidekiq Web UI" do
    it "is not routable for visitors or readers" do
      get "/admin/sidekiq"
      expect(response).to have_http_status(:not_found)

      sign_in_as(create(:user))
      get "/admin/sidekiq"
      expect(response).to have_http_status(:not_found)
    end

    it "is mounted for admins" do
      sign_in_as(create(:user, :admin))
      get "/admin/sidekiq"
      expect(response).to have_http_status(:ok)
    end
  end
end
