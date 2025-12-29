class AlterTableIdleConversationAddColumnStep < ActiveRecord::Migration[7.0]
  def change
    add_column :idle_conversations, :step, :integer, default: 0, null: false
    add_column :idle_conversations, :last_sent_at, :datetime
    add_column :idle_conversations, :additional_attributes, :jsonb, default: {}
  end
end
