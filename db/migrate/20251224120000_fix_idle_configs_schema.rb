class FixIdleConfigsSchema < ActiveRecord::Migration[7.0]
  def up
    # Drop the existing table with incorrect schema
    drop_table :idle_configs, if_exists: true

    # Recreate with correct schema
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

  def down
    drop_table :idle_configs, if_exists: true

    # Restore old schema (for rollback)
    create_table :idle_configs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :agent_id
      t.string :agent_name
      t.string :agent_type
      t.integer :idle_duration_minutes

      t.timestamps
    end
  end
end
