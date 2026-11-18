class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :category, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.string :slug, null: false
      t.text :excerpt
      t.text :body, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :published_at
      t.integer :comments_count, null: false, default: 0

      t.timestamps
    end
    add_index :posts, :slug, unique: true
    # Public listing: WHERE status = 'published' AND published_at <= now ORDER BY published_at DESC
    add_index :posts, [:status, :published_at]
    add_check_constraint :posts, "status IN ('draft', 'published')", name: "posts_status_check"
  end
end
