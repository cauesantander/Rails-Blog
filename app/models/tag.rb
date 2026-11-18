class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  has_many :posts, through: :taggings

  normalizes :name, with: ->(n) { n.squish.downcase }

  validates :name, presence: true, uniqueness: true, length: { maximum: 30 }

  def to_param = name
end
