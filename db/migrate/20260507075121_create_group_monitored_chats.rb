class CreateGroupMonitoredChats < ActiveRecord::Migration[7.0]
  def change
    create_table :group_monitored_chats do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.string :group_id, null: false
      t.string :group_name
      t.boolean :active, default: true
      t.timestamps
    end
    add_index :group_monitored_chats, [:account_id, :group_id], unique: true
  end
end