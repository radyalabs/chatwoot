class UpdateAvailabilityTypeValues < ActiveRecord::Migration[7.0]
  def up
    # Migrate existing data
    Inbox.where(availability_type: 'turn_off_bot').update_all(availability_type: 'turn_on')
    Inbox.where(availability_type: 'turn_off_channel').update_all(availability_type: 'turn_off')

    # Change default value
    change_column_default :inboxes, :availability_type, from: 'turn_off_bot', to: 'turn_on'
  end

  def down
    # Rollback data
    Inbox.where(availability_type: 'turn_on').update_all(availability_type: 'turn_off_bot')
    Inbox.where(availability_type: 'turn_off').update_all(availability_type: 'turn_off_channel')

    # Revert default value
    change_column_default :inboxes, :availability_type, from: 'turn_on', to: 'turn_off_bot'
  end
end
