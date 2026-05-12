class AddDataTypeToContactAttributeKeys < ActiveRecord::Migration[7.0]
  def change
    add_column :contact_attribute_keys, :data_type, :integer, null: false, default: 0
  end
end
