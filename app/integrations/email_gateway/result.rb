module EmailGateway
  # What a successful delivery returns: the provider's id, stored for traceability.
  Result = Data.define(:message_id)
end
