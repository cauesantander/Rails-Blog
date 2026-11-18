require "rails_helper"

RSpec.describe "Health checks" do
  it "/up answers when the app boots" do
    get "/up"
    expect(response).to have_http_status(:ok)
  end

  it "/health reports database and redis status" do
    get "/health"
    body = response.parsed_body
    expect(body["checks"]).to include("database" => true)
    expect(body["checks"]).to have_key("redis")
  end

  it "/health returns 503 when a dependency is down" do
    allow(Sidekiq).to receive(:redis).and_raise(RedisClient::CannotConnectError)
    get "/health"
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to include("status" => "degraded")
  end
end
