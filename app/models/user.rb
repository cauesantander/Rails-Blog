class User < ApplicationRecord
  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/webp image/gif].freeze
  AVATAR_MAX_SIZE = 2.megabytes

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :posts, foreign_key: :author_id, inverse_of: :author, dependent: :restrict_with_error
  has_many :comments, dependent: :destroy
  has_one :subscriber, dependent: :nullify

  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [96, 96]
  end

  enum :role, { reader: "reader", admin: "admin" }, default: :reader, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.squish }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 80 }
  validates :bio, length: { maximum: 500 }
  # bcrypt only uses the first 72 bytes of the password.
  validates :password, length: { minimum: 8, maximum: 72 }, allow_nil: true
  validate :avatar_is_acceptable

  private
    # Active Storage has no built-in validations; checking content type and size
    # here keeps arbitrary files out of the bucket.
    def avatar_is_acceptable
      return unless avatar.attached?

      unless avatar.blob.content_type.in?(AVATAR_CONTENT_TYPES)
        errors.add(:avatar, :invalid_content_type, message: "deve ser PNG, JPEG, WEBP ou GIF")
      end
      if avatar.blob.byte_size > AVATAR_MAX_SIZE
        errors.add(:avatar, :too_large, message: "deve ter no máximo 2 MB")
      end
    end
end
