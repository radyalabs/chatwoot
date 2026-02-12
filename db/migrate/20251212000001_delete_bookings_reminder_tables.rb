class DeleteBookingsReminderTables < ActiveRecord::Migration[7.0]
  def up
    # Remove FK from booking_reminder_logs to booking_records
    if foreign_key_exists?(:booking_reminder_logs, :booking_records)
      remove_foreign_key :booking_reminder_logs, :booking_records
    end

    # Drop in dependency order
    drop_table :booking_reminder_logs, if_exists: true
    drop_table :booking_reminder_configs, if_exists: true
    drop_table :booking_records, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
