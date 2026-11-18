class CreateSubscribers < ActiveRecord::Migration[8.1]
  def change
    create_table :subscribers do |t|
      t.string :email, null: false
      t.string :status, null: false, default: "pending"
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :unsubscribe_token, null: false
      t.datetime :confirmed_at
      t.datetime :unsubscribed_at

      t.timestamps
    end
    add_index :subscribers, :email, unique: true
    add_index :subscribers, :unsubscribe_token, unique: true
    add_index :subscribers, :status
    add_check_constraint :subscribers, "status IN ('pending', 'confirmed', 'unsubscribed')", name: "subscribers_status_check"
  end
end
