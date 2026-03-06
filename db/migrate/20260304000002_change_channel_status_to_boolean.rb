class ChangeChannelStatusToBoolean < ActiveRecord::Migration[7.0]
  def up
    change_column_default :inboxes, :channel_status, nil

    change_column :inboxes, :channel_status,
                  'boolean USING channel_status::boolean'

    change_column_default :inboxes, :channel_status, from: 't', to: true
  end

  def down
    change_column_default :inboxes, :channel_status, nil

    change_column :inboxes, :channel_status, :string

    change_column_default :inboxes, :channel_status, 't'
  end
end
