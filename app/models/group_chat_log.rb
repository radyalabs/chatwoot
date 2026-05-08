# frozen_string_literal: true

# == Schema Information
#
# Table name: group_chat_logs
#
#  id                      :bigint           not null, primary key
#  content                 :text
#  event_type              :string           not null
#  quoted_body             :text
#  raw_payload             :jsonb
#  reaction_emoji          :string
#  sender_jid              :string
#  sender_name             :string
#  sent_at                 :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  group_monitored_chat_id :bigint           not null
#  message_id              :string
#  reaction_target_id      :string
#  replied_to_id           :string
#
# Indexes
#
#  index_group_chat_logs_on_account_id                              (account_id)
#  index_group_chat_logs_on_event_type                              (event_type)
#  index_group_chat_logs_on_group_monitored_chat_id                 (group_monitored_chat_id)
#  index_group_chat_logs_on_group_monitored_chat_id_and_message_id  (group_monitored_chat_id,message_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (group_monitored_chat_id => group_monitored_chats.id)
#
class GroupChatLog < ApplicationRecord
  belongs_to :account
  belongs_to :group_monitored_chat

  validates :event_type, presence: true
  validates :message_id, presence: true

  scope :messages, -> { where(event_type: 'message') }
  scope :reactions, -> { where(event_type: 'message.reaction') }
  scope :for_group, ->(group_id) { joins(:group_monitored_chat).where(group_monitored_chats: { group_id: group_id }) }
end
