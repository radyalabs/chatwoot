class AddIntentStatusToMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :intent_status, :integer, default: 0
    add_index :messages, :intent_status
  end
end
