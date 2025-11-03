class ChangeDefaultFormatForNumberFormatConfigs < ActiveRecord::Migration[7.0]
  def change
    change_column_default :number_format_configs, :format, from: "INV/[NUMBER]", to: "[NUMBER]/[MONTH]/[YEAR]"
  end
end
