class RemoveIntentStatusFromMessages < ActiveRecord::Migration[7.0]
  def change
    remove_column :messages, :intent_status, :integer
  end
end
