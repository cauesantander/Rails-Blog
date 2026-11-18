class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      # String-backed enum: readable in SQL and safe against reordering (see User::ROLES).
      t.string :role, null: false, default: "reader"
      t.text :bio

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_check_constraint :users, "role IN ('reader', 'admin')", name: "users_role_check"
  end
end
