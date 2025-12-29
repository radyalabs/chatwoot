# == Schema Information
#
# Table name: idle_conversations
#
#  id                    :bigint           not null, primary key
#  additional_attributes :jsonb
#  last_sent_at          :datetime
#  status                :integer          default("waiting"), not null
#  step                  :integer          default(0), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#  ai_agent_id           :integer          not null
#  conversation_id       :bigint           not null
#  inbox_id              :integer          not null
#
# Indexes
#
#  index_idle_conversations_on_conversation_id  (conversation_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#
class IdleConversation < ApplicationRecord
  belongs_to :conversation
  enum status: { waiting: 0, executing: 1, completed: 2 }

  scope :with_conversation_status, lambda { |status|
                                     waiting.joins(:conversation).where(conversations: { status: status })
                                   }
  scope :with_unassigned_conversation, lambda {
                                         joins(:conversation).where(conversations: { assignee_id: nil })
                                       }
end
