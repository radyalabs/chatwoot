class AddLastSyncedValueToSheetNumberingConfigs < ActiveRecord::Migration[7.0]
  def up
    add_column :sheet_numbering_configs, :last_synced_value, :integer, null: true

    # Backfill: configs that have been synced (last_synced_at present) should use current_value
    SheetNumberingConfig.where.not(last_synced_at: nil).update_all('last_synced_value = current_value')
  end

  def down
    remove_column :sheet_numbering_configs, :last_synced_value
  end
end
