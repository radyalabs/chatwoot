class AddCascadeDeleteToAgentNotificationSettingsFk < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :agent_notification_settings, :inboxes
    add_foreign_key :agent_notification_settings, :inboxes, on_delete: :cascade
  end
end
