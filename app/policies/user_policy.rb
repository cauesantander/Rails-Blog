class UserPolicy < ApplicationPolicy
  def index? = admin?
  # Admins change other users' roles, never their own (avoids removing the last admin by accident).
  def update_role? = admin? && record != user
end
