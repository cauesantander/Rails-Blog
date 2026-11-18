# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_30_170600) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "campaign_deliveries", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "subscriber_id"
    t.string "email", null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.datetime "locked_at"
    t.datetime "sent_at"
    t.datetime "failed_at"
    t.string "provider_message_id"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "status"], name: "index_campaign_deliveries_on_campaign_id_and_status"
    t.index ["campaign_id", "subscriber_id"], name: "index_campaign_deliveries_on_campaign_id_and_subscriber_id", unique: true
    t.index ["locked_at"], name: "index_campaign_deliveries_on_locked_at", where: "((status)::text = 'sending'::text)"
    t.index ["subscriber_id"], name: "index_campaign_deliveries_on_subscriber_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'sending'::character varying, 'sent'::character varying, 'failed'::character varying, 'skipped'::character varying]::text[])", name: "campaign_deliveries_status_check"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "subject", null: false
    t.text "intro"
    t.bigint "post_id"
    t.bigint "created_by_id", null: false
    t.string "status", default: "draft", null: false
    t.datetime "scheduled_at"
    t.datetime "queued_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "recipients_count", default: 0, null: false
    t.integer "sent_count", default: 0, null: false
    t.integer "failed_count", default: 0, null: false
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_campaigns_on_created_by_id"
    t.index ["post_id"], name: "index_campaigns_on_post_id"
    t.index ["status", "scheduled_at"], name: "index_campaigns_on_status_and_scheduled_at"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'scheduled'::character varying, 'queued'::character varying, 'sending'::character varying, 'sent'::character varying, 'canceled'::character varying]::text[])", name: "campaigns_status_check"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.string "status", default: "visible", null: false
    t.bigint "moderated_by_id"
    t.datetime "moderated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["moderated_by_id"], name: "index_comments_on_moderated_by_id"
    t.index ["post_id", "status", "created_at"], name: "index_comments_on_post_id_and_status_and_created_at"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['visible'::character varying, 'hidden'::character varying]::text[])", name: "comments_status_check"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.bigint "category_id"
    t.string "title", null: false
    t.string "slug", null: false
    t.text "excerpt"
    t.text "body", null: false
    t.string "status", default: "draft", null: false
    t.datetime "published_at"
    t.integer "comments_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_posts_on_author_id"
    t.index ["category_id"], name: "index_posts_on_category_id"
    t.index ["slug"], name: "index_posts_on_slug", unique: true
    t.index ["status", "published_at"], name: "index_posts_on_status_and_published_at"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'published'::character varying]::text[])", name: "posts_status_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subscribers", force: :cascade do |t|
    t.string "email", null: false
    t.string "status", default: "pending", null: false
    t.bigint "user_id"
    t.string "unsubscribe_token", null: false
    t.datetime "confirmed_at"
    t.datetime "unsubscribed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_subscribers_on_email", unique: true
    t.index ["status"], name: "index_subscribers_on_status"
    t.index ["unsubscribe_token"], name: "index_subscribers_on_unsubscribe_token", unique: true
    t.index ["user_id"], name: "index_subscribers_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'confirmed'::character varying, 'unsubscribed'::character varying]::text[])", name: "subscribers_status_check"
  end

  create_table "taggings", force: :cascade do |t|
    t.bigint "post_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "tag_id"], name: "index_taggings_on_post_id_and_tag_id", unique: true
    t.index ["post_id"], name: "index_taggings_on_post_id"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "name", null: false
    t.string "role", default: "reader", null: false
    t.text "bio"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "role::text = ANY (ARRAY['reader'::character varying, 'admin'::character varying]::text[])", name: "users_role_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "campaign_deliveries", "campaigns", on_delete: :cascade
  add_foreign_key "campaign_deliveries", "subscribers", on_delete: :nullify
  add_foreign_key "campaigns", "posts", on_delete: :nullify
  add_foreign_key "campaigns", "users", column: "created_by_id"
  add_foreign_key "comments", "posts", on_delete: :cascade
  add_foreign_key "comments", "users", column: "moderated_by_id", on_delete: :nullify
  add_foreign_key "comments", "users", on_delete: :cascade
  add_foreign_key "posts", "categories", on_delete: :nullify
  add_foreign_key "posts", "users", column: "author_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "subscribers", "users", on_delete: :nullify
  add_foreign_key "taggings", "posts", on_delete: :cascade
  add_foreign_key "taggings", "tags", on_delete: :cascade
end
