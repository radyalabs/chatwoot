class AddAvailabilityTypeToInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :availability_type, :string, default: 'turn_off_bot'
    add_index :inboxes, :availability_type
  end
end
