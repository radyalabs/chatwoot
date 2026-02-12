class CreateAgentNotificationSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :agent_notification_settings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_agent, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.string :category, null: false
      t.string :interest_level
      t.string :message_type, null: false, default: 'personal'
      t.string :receiver_channel_type, null: false, default: 'whatsapp_unofficial'
      t.string :receiver_address, null: false
      t.text :message_template, null: false

      t.timestamps
    end

    add_index :agent_notification_settings, %i[account_id ai_agent_id],
              name: 'idx_agent_notif_settings_on_account_and_agent'
  end
end
