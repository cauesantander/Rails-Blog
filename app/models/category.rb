class Category < ApplicationRecord
  has_many :posts, dependent: :nullify

  normalizes :name, with: ->(n) { n.squish }

  validates :name, presence: true, uniqueness: true, length: { maximum: 50 }
  validates :slug, presence: true, uniqueness: true

  before_validation { self.slug = name.to_s.parameterize if slug.blank? || name_changed? }

  scope :alphabetical, -> { order(:name) }

  def to_param = slug
end
