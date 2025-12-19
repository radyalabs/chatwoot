class CreateSheetNumberingConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :sheet_numbering_configs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_agent, null: false, foreign_key: true
      t.string :prefix
      t.string :format_pattern, null: false, default: '[NUMBER]/[MONTH]/[YEAR]'
      t.integer :current_value, null: false, default: 1
      t.integer :number_padding, null: false, default: 3
      t.string :reset_interval, null: false, default: 'never'

      t.timestamps
    end

    add_index :sheet_numbering_configs, [:account_id, :ai_agent_id], unique: true
  end
end
