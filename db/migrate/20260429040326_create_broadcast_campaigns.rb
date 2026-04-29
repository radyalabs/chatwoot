class CreateBroadcastCampaigns < ActiveRecord::Migration[7.0]
  def change
    create_table :broadcast_campaigns do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :inbox, null: false, foreign_key: true
      
      t.string :target_segment, default: 'all'
      t.text :message_body, null: false
      
      t.boolean :spin_text_enabled, default: false
      t.boolean :unsubscribe_link_enabled, default: false
      
      t.integer :status, default: 0 
      t.datetime :scheduled_at

      t.timestamps
    end
  end
end