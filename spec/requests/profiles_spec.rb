require "rails_helper"

RSpec.describe "Profile" do
  let(:user) { create(:user, password: "password123") }
  let(:png) { Rack::Test::UploadedFile.new(StringIO.new(Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
  )), "image/png", original_filename: "avatar.png") }

  it "requires login" do
    get profile_path
    expect(response).to redirect_to(new_session_path)
  end

  context "when logged in" do
    before { sign_in_as(user) }

    it "shows the profile" do
      get profile_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.name)
    end

    it "updates name and bio" do
      patch profile_path, params: { user: { name: "Novo Nome", bio: "Dev Ruby" } }
      expect(response).to redirect_to(profile_path)
      expect(user.reload.attributes.slice("name", "bio")).to eq("name" => "Novo Nome", "bio" => "Dev Ruby")
    end

    it "uploads an avatar with Active Storage" do
      patch profile_path, params: { user: { name: user.name, avatar: png } }
      expect(user.reload.avatar).to be_attached
      expect(user.avatar.filename.to_s).to eq("avatar.png")
    end

    it "removes the avatar" do
      user.avatar.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
      perform_enqueued_jobs do
        patch profile_path, params: { user: { name: user.name, remove_avatar: "1" } }
      end
      expect(user.reload.avatar).not_to be_attached
    end

    it "requires the current password to change the password" do
      patch profile_path, params: { user: { password: "newpassword1", password_confirmation: "newpassword1", password_challenge: "wrong" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.authenticate("password123")).to be_truthy

      patch profile_path, params: { user: { password: "newpassword1", password_confirmation: "newpassword1", password_challenge: "password123" } }
      expect(user.reload.authenticate("newpassword1")).to be_truthy
    end

    it "cannot escalate its own role" do
      patch profile_path, params: { user: { name: "x", role: "admin" } }
      expect(user.reload).to be_reader
    end
  end
end
