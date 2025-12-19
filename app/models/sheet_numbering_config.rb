# == Schema Information
#
# Table name: sheet_numbering_configs
#
#  id             :bigint           not null, primary key
#  prefix         :string
#  format_pattern :string           default("[NUMBER]/[MONTH]/[YEAR]"), not null
#  current_value  :integer          default(1), not null
#  number_padding :integer          default(3), not null
#  reset_interval :string           default("never"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  ai_agent_id    :bigint           not null
#
# Indexes
#
#  index_sheet_numbering_configs_on_account_id                  (account_id)
#  index_sheet_numbering_configs_on_account_id_and_ai_agent_id  (account_id,ai_agent_id) UNIQUE
#  index_sheet_numbering_configs_on_ai_agent_id                 (ai_agent_id)
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

  validates :ai_agent_id, uniqueness: { scope: :account_id }
  validates :format_pattern, presence: true
  validates :current_value, numericality: { greater_than_or_equal_to: 1 }
  validates :number_padding, numericality: { greater_than_or_equal_to: 1 }
  validates :reset_interval, inclusion: { in: VALID_RESET_INTERVALS }
end
