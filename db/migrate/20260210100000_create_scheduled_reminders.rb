class CreateScheduledReminders < ActiveRecord::Migration[7.0]
  def change
    create_table :scheduled_reminders do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_agent, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true

      # Identity
      t.string :title, null: false
      t.text :description

      # Receiver
      t.string :receiver_channel_type, null: false
      t.string :message_type, null: false, default: 'personal'
      t.string :receiver_address, null: false
      t.string :receiver_name

      # Message content
      t.text :message_template, null: false

      # Schedule
      t.datetime :scheduled_at, null: false
      t.string :timezone, null: false, default: 'UTC'
      t.jsonb :recurrence_rule

      # Recurrence end conditions
      t.datetime :ends_at
      t.integer :ends_after_count

      # Execution tracking
      t.datetime :next_occurrence_at
      t.integer :occurrence_count, default: 0
      t.datetime :last_sent_at

      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :scheduled_reminders, %i[account_id ai_agent_id]
    add_index :scheduled_reminders, %i[next_occurrence_at enabled],
              name: 'idx_scheduled_reminders_due'
  end
end
