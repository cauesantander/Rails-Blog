class PostPolicy < ApplicationPolicy
  def show? = record.visible? || admin?
  def index? = admin?
  def create? = admin?
  def update? = admin?
  def destroy? = admin?
  def publish? = admin?
  def unpublish? = admin?

  # Visitors only ever see visible posts; drafts behave as "not found" for them.
  class Scope < Scope
    def resolve
      user&.admin? ? scope.all : scope.visible
    end
  end
end
