class AddUniqueBusinessKeyIndexToScheduledReminders < ActiveRecord::Migration[7.0]
  def change
    add_index :scheduled_reminders,
              %i[account_id ai_agent_id inbox_id receiver_address title],
              unique: true,
              name: 'idx_scheduled_reminders_business_key'
  end
end
