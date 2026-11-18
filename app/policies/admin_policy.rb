# Headless policy guarding the whole /admin namespace: `authorize :admin, :access?`.
class AdminPolicy < ApplicationPolicy
  def access? = admin?
end
