class UpdateRemindersTable < ActiveRecord::Migration[7.0]
  def change
    add_column :reminders, :service_id, :string
    add_column :reminders, :message, :string
  end
end