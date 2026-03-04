class RenameAvailabilityTypeToChannelStatus < ActiveRecord::Migration[7.0]
  def up
    rename_column :inboxes, :availability_type, :channel_status

    Inbox.where(channel_status: 'turn_on').update_all(channel_status: true)
    Inbox.where(channel_status: 'turn_off').update_all(channel_status: false)

    change_column_default :inboxes, :channel_status, from: 'turn_on', to: true
  end

  def down
    Inbox.where(channel_status: true).update_all(channel_status: 'turn_on')
    Inbox.where(channel_status: false).update_all(channel_status: 'turn_off')

    change_column_default :inboxes, :channel_status, from: true, to: 'turn_on'

    rename_column :inboxes, :channel_status, :availability_type
  end
end
