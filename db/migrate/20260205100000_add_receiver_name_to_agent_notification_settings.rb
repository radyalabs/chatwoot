class AddReceiverNameToAgentNotificationSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :agent_notification_settings, :receiver_name, :string
  end
end
