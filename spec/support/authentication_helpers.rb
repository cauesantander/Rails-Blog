module AuthenticationHelpers
  # Logs in through the real endpoint, so request specs exercise the session cookie flow.
  def sign_in_as(user, password: "password123")
    post session_path, params: { email_address: user.email_address, password: }
    expect(response).to redirect_to(root_url)
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
