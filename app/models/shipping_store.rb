# == Schema Information
#
# Table name: shipping_stores
#
#  id               :bigint           not null, primary key
#  address          :text             not null
#  courier_settings :jsonb            not null
#  is_enabled       :boolean          default(TRUE), not null
#  latitude         :decimal(10, 6)
#  longitude        :decimal(10, 6)
#  name             :string           not null
#  pickup_settings  :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  ai_agent_id      :bigint           not null
#
# Indexes
#
#  index_shipping_stores_on_account_id                  (account_id)
#  index_shipping_stores_on_ai_agent_id                 (ai_agent_id)
#  index_shipping_stores_on_ai_agent_id_and_is_enabled  (ai_agent_id,is_enabled)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (ai_agent_id => ai_agents.id)
#
class ShippingStore < ApplicationRecord
  belongs_to :account
  belongs_to :ai_agent

  validates :name, presence: true
  validates :address, presence: true
  validates :latitude, :longitude, numericality: true, allow_nil: true
end
