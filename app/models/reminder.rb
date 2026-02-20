# == Schema Information
#
# Table name: reminders
#
#  id                  :bigint           not null, primary key
#  contact             :string
#  customer_name       :string
#  last_sent_at        :datetime
#  message             :string
#  scheduled_at        :datetime         not null
#  sent_reminder_count :integer          default(0), not null
#  service_location    :string
#  service_name        :string
#  service_type        :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  ai_agent_id         :bigint           not null
#  conversation_id     :bigint           not null
#  inbox_id            :bigint           not null
#  service_id          :string
#
# Indexes
#
#  index_reminders_on_account_id                        (account_id)
#  index_reminders_on_account_id_and_scheduled_at       (account_id,scheduled_at)
#  index_reminders_on_ai_agent_id                       (ai_agent_id)
#  index_reminders_on_conversation_id                   (conversation_id)
#  index_reminders_on_conversation_id_and_scheduled_at  (conversation_id,scheduled_at)
#  index_reminders_on_inbox_id                          (inbox_id)
#  reminders_unique_idx                                 (account_id,inbox_id,ai_agent_id,conversation_id,service_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (ai_agent_id => ai_agents.id)
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (inbox_id => inboxes.id) ON DELETE => cascade
#

class Reminder < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :ai_agent
  belongs_to :conversation

  validates :scheduled_at, presence: true

  scope :pending, -> { where(sent_reminder_count: 0) }
  scope :due_for_reminder, lambda { |minutes_before|
    now = Time.current
    where('scheduled_at <= ?', now + minutes_before.minutes)
      .where('scheduled_at > ?', now)
      .where(sent_reminder_count: 0)
  }

  def mark_as_sent!(message_content = nil)
    update!(
      sent_reminder_count: sent_reminder_count + 1,
      last_sent_at: Time.current,
      message: message_content
    )
  end
end
