require 'administrate/base_dashboard'

class EmailSenderDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number.with_options(searchable: true),
    to_email: Field::String.with_options(searchable: true),
    from_email: Field::String,
    subject: Field::String.with_options(searchable: true),
    status: Field::Select.with_options(collection: EmailSender.statuses.keys),
    source: Field::Select.with_options(collection: EmailSender.sources.keys),
    body: Field::Text,
    error_message: Field::String,
    created_at: BrowserDatetimeField,
    updated_at: BrowserDatetimeField
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    to_email
    subject
    status
    source
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    to_email
    from_email
    subject
    status
    source
    body
    error_message
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = [].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(email_sender)
    "Email ##{email_sender.id}"
  end
end
