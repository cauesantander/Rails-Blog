module EmailGatewayHelpers
  def email_gateway = EmailGateway.adapter
  def gateway_deliveries = EmailGateway.adapter.deliveries
end

RSpec.configure do |config|
  config.include EmailGatewayHelpers
end
