# == Schema Information
#
# Table name: agent_notification_settings
#
#  id                    :bigint           not null, primary key
#  category              :string
#  interest_level        :string
#  message_template      :text             not null
#  message_type          :string           default("personal"), not null
#  receiver_address      :string           not null
#  receiver_channel_type :string           default("whatsapp_unofficial"), not null
#  receiver_name         :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  ai_agent_id           :bigint           not null
#  inbox_id              :bigint           not null
#
# Indexes
#
#  idx_agent_notif_settings_on_account_and_agent     (account_id,ai_agent_id)
#  index_agent_notification_settings_on_account_id   (account_id)
#  index_agent_notification_settings_on_ai_agent_id  (ai_agent_id)
#  index_agent_notification_settings_on_inbox_id     (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (ai_agent_id => ai_agents.id)
#  fk_rails_...  (inbox_id => inboxes.id) ON DELETE => cascade
#
class AgentNotificationSetting < ApplicationRecord
  belongs_to :account
  belongs_to :ai_agent
  belongs_to :inbox, -> { unscope(where: :deleted_at) }

  validates :message_type, presence: true, inclusion: { in: %w[personal group] }
  validates :receiver_address, presence: true
  validates :message_template, presence: true
end
