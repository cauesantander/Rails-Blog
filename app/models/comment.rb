class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true
  belongs_to :user
  belongs_to :moderated_by, class_name: "User", optional: true

  # Post-moderation: comments are visible right away and admins can hide them.
  enum :status, { visible: "visible", hidden: "hidden" }, default: :visible, validate: true

  validates :body, presence: true, length: { maximum: 2_000 }

  scope :chronological, -> { order(:created_at, :id) }

  def hide!(by:)
    update!(status: :hidden, moderated_by: by, moderated_at: Time.current)
  end

  def restore!(by:)
    update!(status: :visible, moderated_by: by, moderated_at: Time.current)
  end
end
