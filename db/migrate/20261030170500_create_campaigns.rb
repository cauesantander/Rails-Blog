class CreateCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :campaigns do |t|
      t.string :subject, null: false
      t.text :intro
      t.references :post, foreign_key: { on_delete: :nullify }
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "draft"
      t.datetime :scheduled_at
      t.datetime :queued_at
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :recipients_count, null: false, default: 0
      t.integer :sent_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.text :last_error

      t.timestamps
    end
    # Scheduler query: WHERE status = 'scheduled' AND scheduled_at <= now
    add_index :campaigns, [:status, :scheduled_at]
    add_check_constraint :campaigns,
      "status IN ('draft', 'scheduled', 'queued', 'sending', 'sent', 'canceled')",
      name: "campaigns_status_check"
  end
end
