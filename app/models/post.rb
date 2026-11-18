class Post < ApplicationRecord
  belongs_to :author, class_name: "User"
  belongs_to :category, optional: true
  has_many :comments, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings
  has_many :campaigns, dependent: :nullify

  enum :status, { draft: "draft", published: "published" }, default: :draft, validate: true

  validates :title, presence: true, length: { maximum: 150 }
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "deve conter apenas letras minúsculas, números e hífens" }
  validates :body, presence: true
  validates :excerpt, length: { maximum: 300 }
  validates :published_at, presence: true, if: :published?

  before_validation :generate_slug, if: -> { slug.blank? && title.present? }
  before_validation { self.published_at ||= Time.current if published? }

  # "Visible to the public" = published and not scheduled for the future.
  scope :visible, -> { published.where(published_at: ..Time.current) }
  scope :recent, -> { order(published_at: :desc, id: :desc) }
  scope :with_tag, ->(name) { joins(:tags).where(tags: { name: name.to_s.downcase }) }

  def to_param = slug

  def publish!(at: Time.current)
    update!(status: :published, published_at: published_at || at)
  end

  def unpublish!
    update!(status: :draft)
  end

  def visible?
    published? && published_at.present? && published_at <= Time.current
  end

  # Comma separated tag names, used by the admin form ("ruby, rails, sidekiq").
  def tag_list
    tags.map(&:name).join(", ")
  end

  def tag_list=(names)
    self.tags = names.to_s.split(",").map { it.squish.downcase }.compact_blank.uniq.map do |name|
      Tag.find_or_create_by!(name:)
    end
  end

  def summary
    excerpt.presence || body.to_s.truncate(200, separator: " ")
  end

  private
    def generate_slug
      base = title.parameterize.presence || "post"
      candidate = base
      suffix = 2
      while Post.where.not(id:).exists?(slug: candidate)
        candidate = "#{base}-#{suffix}"
        suffix += 1
      end
      self.slug = candidate
    end
end
