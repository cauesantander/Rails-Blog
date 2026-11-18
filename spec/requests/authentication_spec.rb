require "rails_helper"

RSpec.describe "Authentication" do
  let!(:user) { create(:user, email_address: "ana@example.com", password: "password123") }

  describe "sign up" do
    it "creates a reader account and logs in" do
      expect {
        post registration_path, params: { user: { name: "Bia", email_address: "bia@example.com",
                                                  password: "password123", password_confirmation: "password123" } }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(root_path)
      expect(User.last).to be_reader
      expect(cookies[:session_id]).to be_present
    end

    it "ignores attempts to self-assign the admin role" do
      post registration_path, params: { user: { name: "Eve", email_address: "eve@example.com", password: "password123",
                                                password_confirmation: "password123", role: "admin" } }
      expect(User.find_by(email_address: "eve@example.com")).to be_reader
    end

    it "re-renders the form with errors" do
      post registration_path, params: { user: { name: "", email_address: "bad", password: "123", password_confirmation: "321" } }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "login / logout" do
    it "logs in with valid credentials and creates a session record" do
      expect {
        post session_path, params: { email_address: "ana@example.com", password: "password123" }
      }.to change(Session, :count).by(1)
      expect(response).to redirect_to(root_url)
    end

    it "rejects invalid credentials" do
      post session_path, params: { email_address: "ana@example.com", password: "wrong" }
      expect(response).to redirect_to(new_session_path)
      expect(Session.count).to eq(0)
    end

    it "returns to the originally requested page after login" do
      get edit_profile_path
      expect(response).to redirect_to(new_session_path)
      post session_path, params: { email_address: "ana@example.com", password: "password123" }
      expect(response).to redirect_to(edit_profile_url)
    end

    it "logs out destroying the session" do
      sign_in_as(user)
      expect { delete session_path }.to change(Session, :count).by(-1)
      get profile_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "password reset" do
    it "e-mails reset instructions without revealing whether the account exists" do
      expect { post passwords_path, params: { email_address: "ana@example.com" } }
        .to have_enqueued_mail(PasswordsMailer, :reset)
      expect(response).to redirect_to(new_session_path)

      expect { post passwords_path, params: { email_address: "ghost@example.com" } }.not_to have_enqueued_mail
      expect(response).to redirect_to(new_session_path)
    end

    it "updates the password with a valid token and kills existing sessions" do
      sign_in_as(user)
      token = user.password_reset_token

      put password_path(token), params: { password: "newpassword1", password_confirmation: "newpassword1" }

      expect(response).to redirect_to(new_session_path)
      expect(user.reload.authenticate("newpassword1")).to be_truthy
      expect(user.sessions).to be_empty
    end

    it "rejects invalid tokens" do
      get edit_password_path("invalid")
      expect(response).to redirect_to(new_password_path)
    end
  end
end
