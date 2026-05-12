# == Schema Information
#
# Table name: contact_attribute_keys
#
#  id         :bigint           not null, primary key
#  data_type  :integer          default("text"), not null
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
  validates :data_type, presence: true

  enum data_type: { text: 0, number: 1, date: 2 }

  after_destroy :remove_key_from_contacts

  def attribute_display_type
    data_type
  end

  private

  def remove_key_from_contacts
    quoted = ActiveRecord::Base.connection.quote(key)
    account.contacts.update_all("custom_attributes = custom_attributes - #{quoted}")
  end
end
