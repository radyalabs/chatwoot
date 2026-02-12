class CreateIdleConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :idle_configs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_agent, null: false, foreign_key: true
      t.boolean :enabled, default: true, null: false
      t.integer :duration, default: 30, null: false
      t.string :action, default: 'resolve', null: false
      t.text :message

      t.timestamps
    end

    add_index :idle_configs, [:account_id, :ai_agent_id], unique: true
  end
end
