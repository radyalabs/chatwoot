class RenameAvailabilityTypeToChannelStatus < ActiveRecord::Migration[7.0]
  def up
    rename_column :inboxes, :availability_type, :channel_status

    execute("UPDATE inboxes SET channel_status = true WHERE channel_status = 'turn_on'")
    execute("UPDATE inboxes SET channel_status = false WHERE channel_status = 'turn_off'")

    change_column_default :inboxes, :channel_status, from: 'turn_on', to: true
  end

  def down
    execute("UPDATE inboxes SET channel_status = 'turn_on' WHERE channel_status = true")
    execute("UPDATE inboxes SET channel_status = 'turn_off' WHERE channel_status = false")

    change_column_default :inboxes, :channel_status, from: true, to: 'turn_on'

    rename_column :inboxes, :channel_status, :availability_type
  end
end
