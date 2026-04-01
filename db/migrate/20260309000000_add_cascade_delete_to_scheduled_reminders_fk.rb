class AddCascadeDeleteToScheduledRemindersFk < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :scheduled_reminders, :inboxes
    add_foreign_key :scheduled_reminders, :inboxes, on_delete: :cascade

    remove_foreign_key :scheduled_reminders, :accounts
    add_foreign_key :scheduled_reminders, :accounts, on_delete: :cascade

    remove_foreign_key :scheduled_reminders, :ai_agents
    add_foreign_key :scheduled_reminders, :ai_agents, on_delete: :cascade
  end
end
