class AddCaptainWelcomeSourceMessageIdToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :captain_welcome_source_message_id, :bigint
  end
end
