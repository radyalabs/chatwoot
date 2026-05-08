# == Schema Information
#
# Table name: broadcast_campaigns
#
#  id                       :bigint           not null, primary key
#  message_body             :text             not null
#  scheduled_at             :datetime
#  spin_text_enabled        :boolean          default(FALSE)
#  status                   :integer          default("draft")
#  target_segment           :string           default("all")
#  unsubscribe_link_enabled :boolean          default(FALSE)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  inbox_id                 :bigint           not null
#
# Indexes
#
#  index_broadcast_campaigns_on_account_id  (account_id)
#  index_broadcast_campaigns_on_inbox_id    (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
class BroadcastCampaign < ApplicationRecord
  # Relasi
  belongs_to :account
  belongs_to :inbox

  enum status: { draft: 0, processing: 1, completed: 2, failed: 3 }

  # Validasi
  validates :message_body, presence: true
  validates :target_segment, presence: true

  validate :account_active?

  private

  def account_active?
    errors.add(:account, 'is suspended') if account.suspended?
  end
end
