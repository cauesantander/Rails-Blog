# Routing constraint for mounted Rack apps (Sidekiq::Web) that don't go through
# ApplicationController and therefore can't use the Authentication concern/Pundit.
class AdminConstraint
  def matches?(request)
    session_id = request.cookie_jar.signed[:session_id]
    session_id.present? && Session.find_by(id: session_id)&.user&.admin?
  end
end
