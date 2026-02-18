class AddCascadeDeleteToRemindersFk < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :reminders, :inboxes
    add_foreign_key :reminders, :inboxes, on_delete: :cascade

    remove_foreign_key :reminders, :conversations
    add_foreign_key :reminders, :conversations, on_delete: :cascade
  end
end
