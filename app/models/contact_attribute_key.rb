# == Schema Information
#
# Table name: contact_attribute_keys
#
#  id         :bigint           not null, primary key
#  key        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_contact_attribute_keys_on_account_id          (account_id)
#  index_contact_attribute_keys_on_account_id_and_key  (account_id,key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class ContactAttributeKey < ApplicationRecord
  belongs_to :account
  validates :key, presence: true, uniqueness: { scope: :account_id }

  after_destroy :remove_key_from_contacts

  private

  def remove_key_from_contacts
    quoted = ActiveRecord::Base.connection.quote(key)
    account.contacts.update_all("custom_attributes = custom_attributes - #{quoted}")
  end
end
