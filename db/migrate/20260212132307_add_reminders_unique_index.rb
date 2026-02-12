class AddRemindersUniqueIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :reminders,
              [:account_id, :inbox_id, :ai_agent_id, :conversation_id, :service_id],
              unique: true,
              name: 'reminders_unique_idx'
  end
end
