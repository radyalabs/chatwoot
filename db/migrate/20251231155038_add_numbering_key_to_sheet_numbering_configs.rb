class AddNumberingKeyToSheetNumberingConfigs < ActiveRecord::Migration[7.0]
  def up
    # Add numbering_key column with default value
    add_column :sheet_numbering_configs, :numbering_key, :string, null: false, default: 'default'

    # Remove old unique index (account_id, ai_agent_id)
    remove_index :sheet_numbering_configs, [:account_id, :ai_agent_id], if_exists: true

    # Add new unique index (account_id, ai_agent_id, numbering_key)
    add_index :sheet_numbering_configs, [:account_id, :ai_agent_id, :numbering_key],
              unique: true,
              name: 'idx_sheet_numbering_configs_unique_key'
  end

  def down
    # Remove new unique index
    remove_index :sheet_numbering_configs, name: 'idx_sheet_numbering_configs_unique_key', if_exists: true

    # Re-add old unique index
    add_index :sheet_numbering_configs, [:account_id, :ai_agent_id], unique: true

    # Remove numbering_key column
    remove_column :sheet_numbering_configs, :numbering_key
  end
end
