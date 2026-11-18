class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :post, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.text :body, null: false
      t.string :status, null: false, default: "visible"
      t.references :moderated_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :moderated_at

      t.timestamps
    end
    add_index :comments, [:post_id, :status, :created_at]
    add_check_constraint :comments, "status IN ('visible', 'hidden')", name: "comments_status_check"
  end
end
