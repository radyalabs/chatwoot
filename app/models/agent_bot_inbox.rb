# == Schema Information
#
# Table name: agent_bot_inboxes
#
#  id          :bigint           not null, primary key
#  status      :integer          default("active")
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :integer
#  ai_agent_id :integer
#  inbox_id    :integer
#
# Indexes
#
#  index_agent_bot_inboxes_on_ai_agent_id  (ai_agent_id)
#

class AgentBotInbox < ApplicationRecord
  validates :inbox_id, presence: true
  validates :ai_agent_id, presence: true
  before_validation :ensure_account_id

  belongs_to :inbox, -> { unscope(where: :deleted_at) }
  belongs_to :ai_agent
  belongs_to :account

  enum status: { active: 0, inactive: 1 }

  scope :with_ai_agent, -> { where.not(ai_agent_id: nil) }

  private

  def ensure_account_id
    self.account_id = inbox&.account_id
  end
end
