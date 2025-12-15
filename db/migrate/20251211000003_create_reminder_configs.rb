class CreateReminderConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :reminder_configs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_agent, null: false, foreign_key: true
      t.boolean :enabled, default: false, null: false
      t.integer :minutes_before_booking, default: 60, null: false
      t.text :message_template

      t.timestamps
    end

    add_index :reminder_configs, [:account_id, :ai_agent_id], unique: true
  end
end
