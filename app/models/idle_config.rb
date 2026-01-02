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
#  index_idle_configs_on_account_id_and_agent_id  (account_id,agent_id) UNIQUE
#

class IdleConfig < ApplicationRecord
  belongs_to :account
  belongs_to :ai_agent

  validates :ai_agent_id, uniqueness: { scope: :account_id }
  validates :duration, numericality: { greater_than: 0 }

  VALID_ACTIONS = %w[resolve message].freeze

  scope :duration_for_ai_agent, lambda { |ai_agent_id|
                                  where(ai_agent_id: ai_agent_id).pick(:duration)
                                }
end
