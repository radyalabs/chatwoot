class BroadcastTemplate < ActiveRecord::Migration[7.0]
  def change
    create_table :broadcast_templates do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :message_body, null: false

      t.timestamps
    end
  end
end
