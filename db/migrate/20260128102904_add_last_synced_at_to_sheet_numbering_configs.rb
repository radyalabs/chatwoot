class AddLastSyncedAtToSheetNumberingConfigs < ActiveRecord::Migration[7.0]
  def up
    add_column :sheet_numbering_configs, :last_synced_at, :datetime, null: true

    # Backfill: configs with current_value > 1 have likely been synced by jangkau
    SheetNumberingConfig.where('current_value > 1').update_all('last_synced_at = updated_at')
  end

  def down
    remove_column :sheet_numbering_configs, :last_synced_at
  end
end
