# == Schema Information
#
# Table name: broadcast_templates
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  message_body  :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#
# Indexes
#
#  index_broadcast_templates_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class BroadcastTemplate < ApplicationRecord
  # Relasi
  belongs_to :account

  # Validasi
  validates :name, presence: true
  validates :message_body, presence: true

  # Memastikan akun tidak sedang disuspend
  validate :account_active?

  private

  def account_active?
    errors.add(:account, 'is suspended') if account.suspended?
  end
end