class MakeCategoryOptionalInAgentNotificationSettings < ActiveRecord::Migration[7.0]
  def change
    change_column_null :agent_notification_settings, :category, true
  end
end
