class CreateOperationalHours < ActiveRecord::Migration[7.0]
  def change
    create_table :operational_hours do |t|
      t.references :agent_bot, null: false, foreign_key: true
      t.integer :day_of_week, null: false
      t.integer :open_hour
      t.integer :open_minute
      t.integer :close_hour
      t.integer :close_minute
      t.boolean :open_allday, default: false
      t.boolean :close_allday, default: false
      t.timestamps
    end

    add_index :operational_hours, [:day_of_week, :agent_bot_id], unique: true
  end
end
