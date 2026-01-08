class Webhooks::GowaEventJob < ApplicationJob
  queue_as :default

  ALLOWED_EVENTS = %w[
    message
    message.edited
  ].freeze

  def perform(payload)
    event = payload['event']
    return unless ALLOWED_EVENTS.include?(event)

    device_id = payload['device_id']
    data      = payload['payload']

    case event
    when 'message'
      handle_message(device_id, data)
    when 'message.edited'
      handle_message_edited(device_id, data)
    end
  end

  private

  def handle_message(device_id, data); end
end
