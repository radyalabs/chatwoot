class AddCascadeDeleteToScheduledRemindersFk < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :scheduled_reminders, :inboxes, if_exists: true
    add_foreign_key :scheduled_reminders, :inboxes, on_delete: :cascade

    remove_foreign_key :scheduled_reminders, :accounts, if_exists: true
    add_foreign_key :scheduled_reminders, :accounts, on_delete: :cascade

    remove_foreign_key :scheduled_reminders, :ai_agents, if_exists: true
    add_foreign_key :scheduled_reminders, :ai_agents, on_delete: :cascade
  end
end
