class CreateIdleConversation < ActiveRecord::Migration[7.0]
  def change
    create_table :idle_conversations do |t|
      t.references :conversation, null: false, foreign_key: true
      t.integer :inbox_id, null: false
      t.integer :account_id, null: false
      t.integer :ai_agent_id, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
