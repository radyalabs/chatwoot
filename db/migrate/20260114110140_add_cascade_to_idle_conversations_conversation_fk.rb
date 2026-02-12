class AddCascadeToIdleConversationsConversationFk < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :idle_conversations, :conversations

    add_foreign_key :idle_conversations, :conversations, column: :conversation_id, on_delete: :cascade
  end
end
