class AddAiSummaryToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :ai_summary, :text
    add_column :conversations, :ai_summary_generated_at, :datetime
  end
end
