# == Schema Information
#
# Table name: idle_configs
#
#  id          :bigint           not null, primary key
#  action      :string           default("resolve"), not null
#  duration    :integer          default(30), not null
#  enabled     :boolean          default(TRUE), not null
#  message     :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  ai_agent_id :bigint           not null
#
# Indexes
#
#  index_idle_configs_on_account_id                  (account_id)
#  index_idle_configs_on_account_id_and_ai_agent_id  (account_id,ai_agent_id) UNIQUE
#  index_idle_configs_on_ai_agent_id                 (ai_agent_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (ai_agent_id => ai_agents.id)
#

class IdleConfig < ApplicationRecord
  belongs_to :account
  belongs_to :ai_agent

  validates :ai_agent_id, uniqueness: { scope: :account_id }
  validates :duration, numericality: { greater_than: 0 }

  VALID_ACTIONS = %w[resolve message].freeze
end
