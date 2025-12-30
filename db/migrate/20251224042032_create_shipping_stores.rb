class CreateShippingStores < ActiveRecord::Migration[7.0]
  def change
    create_table :shipping_stores do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_agent, null: false, foreign_key: true
      
      t.string :name, null: false
      t.text :address, null: false
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.jsonb :courier_settings, default: {}, null: false
      t.jsonb :pickup_settings, default: {}, null: false
      
      t.boolean :is_enabled, default: true, null: false

      t.timestamps
    end
    
    add_index :shipping_stores, [:ai_agent_id, :is_enabled]
  end
end