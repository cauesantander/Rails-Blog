class CreateCampaignDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :campaign_deliveries do |t|
      t.references :campaign, null: false, foreign_key: { on_delete: :cascade }, index: false
      # Nullable: deleting a subscriber keeps the delivery history (email is snapshotted below).
      t.references :subscriber, foreign_key: { on_delete: :nullify }
      t.string :email, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.datetime :locked_at
      t.datetime :sent_at
      t.datetime :failed_at
      t.string :provider_message_id
      t.text :last_error

      t.timestamps
    end
    # Idempotency at the database level: one delivery per subscriber per campaign,
    # no matter how many times the dispatcher runs.
    add_index :campaign_deliveries, [:campaign_id, :subscriber_id], unique: true
    add_index :campaign_deliveries, [:campaign_id, :status]
    # Recovery job: WHERE status = 'sending' AND locked_at < ?
    add_index :campaign_deliveries, :locked_at, where: "status = 'sending'"
    add_check_constraint :campaign_deliveries,
      "status IN ('pending', 'sending', 'sent', 'failed', 'skipped')",
      name: "campaign_deliveries_status_check"
  end
end
