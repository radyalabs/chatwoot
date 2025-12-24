# == Schema Information
#
# Table name: idle_configs
#
#  id                    :bigint           not null, primary key
#  agent_name            :string
#  agent_type            :string
#  idle_duration_minutes :integer          default(30)
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#  agent_id              :string           not null
#
# Indexes
#
#  index_idle_configs_on_account_id_and_agent_id  (account_id,agent_id) UNIQUE
#

class IdleConfig < ApplicationRecord
  alias_attribute :ai_agent_id, :agent_id
  alias_attribute :duration, :idle_duration_minutes
  
  belongs_to :account
  belongs_to :ai_agent, class_name: 'AiAgent', foreign_key: 'agent_id', optional: true

  validates :ai_agent_id, uniqueness: { scope: :account_id }
  validates :duration, numericality: { greater_than: 0 }
  # validates :action, inclusion: { in: %w[resolve message] }

  VALID_ACTIONS = %w[resolve message].freeze
end
