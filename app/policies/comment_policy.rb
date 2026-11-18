class CommentPolicy < ApplicationPolicy
  def create? = user.present? && record.post.visible?
  # Authors may delete their own comments; admins may delete any comment.
  def destroy? = admin? || (user.present? && record.user_id == user.id)
  def moderate? = admin?
end
