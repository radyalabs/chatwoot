require 'administrate/base_dashboard'

class AccountTimelineDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    name: Field::String,
    email: Field::String,
    created_at: BrowserDatetimeField,
    last_sign_in_at: BrowserDatetimeField,
    sign_in_count: Field::Number,
    confirmed_at: BrowserDatetimeField,
    accounts: Field::HasMany
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    name
    email
    created_at
    last_sign_in_at
    sign_in_count
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    email
    created_at
    confirmed_at
    last_sign_in_at
    current_sign_in_at
    sign_in_count
    accounts
  ].freeze

  FORM_ATTRIBUTES = [].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(account_timeline)
    "#{account_timeline.name} (#{account_timeline.email})"
  end
end
