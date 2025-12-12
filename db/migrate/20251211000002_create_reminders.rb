class CreateReminders < ActiveRecord::Migration[7.0]
  def change
    create_table :reminders do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.references :ai_agent, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.datetime :scheduled_at, null: false
      t.string :contact
      t.string :customer_name
      t.string :service_name
      t.string :service_type
      t.string :service_location
      t.integer :sent_reminder_count, default: 0, null: false
      t.datetime :last_sent_at

      t.timestamps
    end

    add_index :reminders, [:account_id, :scheduled_at]
    add_index :reminders, [:conversation_id, :scheduled_at]
  end
end