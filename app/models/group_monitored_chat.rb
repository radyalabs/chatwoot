# frozen_string_literal: true

# == Schema Information
#
# Table name: group_monitored_chats
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE)
#  group_name :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  group_id   :string           not null
#  inbox_id   :bigint           not null
#
# Indexes
#
#  index_group_monitored_chats_on_account_id               (account_id)
#  index_group_monitored_chats_on_account_id_and_group_id  (account_id,group_id) UNIQUE
#  index_group_monitored_chats_on_inbox_id                 (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
class GroupMonitoredChat < ApplicationRecord
  belongs_to :account
  belongs_to :inbox

  validates :group_id, presence: true
  validates :group_id, uniqueness: { scope: :account_id }

  scope :active, -> { where(active: true) }
  scope :for_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }
end
