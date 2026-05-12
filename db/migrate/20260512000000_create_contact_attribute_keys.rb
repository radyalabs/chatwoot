class CreateContactAttributeKeys < ActiveRecord::Migration[7.0]
  def change
    create_table :contact_attribute_keys do |t|
      t.references :account, null: false, foreign_key: true
      t.string :key, null: false
      t.timestamps
    end

    add_index :contact_attribute_keys, [:account_id, :key], unique: true
  end
end
