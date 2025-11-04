class ChangeDefaultFormatForNumberFormatConfigs < ActiveRecord::Migration[7.0]
  def change
    change_column_default :number_format_configs, :format, from: "INV/[NUMBER]", to: "[NUMBER]/[MONTH]/[YEAR]"
    add_column :number_format_configs, :prefix, :string, default: ''
    add_column :number_format_configs, :number_digits, :integer, default: 3
  end
end
