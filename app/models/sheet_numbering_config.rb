# == Schema Information
#
# Table name: sheet_numbering_configs
#
#  id             :bigint           not null, primary key
#  current_value  :integer          default(1), not null
#  format_pattern :string           default("[NUMBER]/[MONTH]/[YEAR]"), not null
#  number_padding :integer          default(3), not null
#  numbering_key  :string           default("default"), not null
#  prefix         :string
#  reset_interval :string           default("never"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  ai_agent_id    :bigint           not null
#
# Indexes
#
#  idx_sheet_numbering_configs_unique_key        (account_id,ai_agent_id,numbering_key) UNIQUE
#  index_sheet_numbering_configs_on_account_id   (account_id)
#  index_sheet_numbering_configs_on_ai_agent_id  (ai_agent_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (ai_agent_id => ai_agents.id)
#

class SheetNumberingConfig < ApplicationRecord
  belongs_to :account
  belongs_to :ai_agent

  VALID_RESET_INTERVALS = %w[never month year].freeze

  # Unique constraint now includes numbering_key to support multiple configs per ai_agent
  validates :ai_agent_id, uniqueness: { scope: [:account_id, :numbering_key] }
  validates :format_pattern, presence: true
  validates :current_value, numericality: { greater_than_or_equal_to: 1 }
  validates :number_padding, numericality: { greater_than_or_equal_to: 1 }
  validates :reset_interval, inclusion: { in: VALID_RESET_INTERVALS }
  validates :numbering_key, presence: true
end
