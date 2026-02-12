class AddIsConvertToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :is_convert, :boolean, default: false, null: false
  end
end
