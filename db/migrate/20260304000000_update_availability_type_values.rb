class UpdateAvailabilityTypeValues < ActiveRecord::Migration[7.0]
  def up
    # Migrate existing data
    execute("UPDATE inboxes SET availability_type = 'turn_on' WHERE availability_type = 'turn_off_bot'")
    execute("UPDATE inboxes SET availability_type = 'turn_off' WHERE availability_type = 'turn_off_channel'")

    # Change default value
    change_column_default :inboxes, :availability_type, from: 'turn_off_bot', to: 'turn_on'
  end

  def down
    # Rollback data
    execute("UPDATE inboxes SET availability_type = 'turn_off_bot' WHERE availability_type = 'turn_on'")
    execute("UPDATE inboxes SET availability_type = 'turn_off_channel' WHERE availability_type = 'turn_off'")

    # Revert default value
    change_column_default :inboxes, :availability_type, from: 'turn_on', to: 'turn_off_bot'
  end
end
