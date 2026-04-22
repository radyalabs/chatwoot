class AddNotifyThresholdToSubscriptionUsage < ActiveRecord::Migration[7.0]
  def change
    add_column :subscription_usage, :last_notify_mau_threshold, :integer, default: 0, null: false
    add_column :subscription_usage, :last_notify_ai_response_threshold, :integer, default: 0, null: false
  end
end
