class Webhooks::GowaEventJob < ApplicationJob
  queue_as :default

  ALLOWED_EVENTS = %w[
    message
    message.edited
  ].freeze

  def perform(params) # rubocop:disable Metrics/CyclomaticComplexity
    event = params['event']
    return unless ALLOWED_EVENTS.include?(event)

    phone_number = params['device_id'].split('@').first
    channel = Channel::WhatsappUnofficial.find_by(phone_number: phone_number)
    return unless channel

    payload = params['payload'] || {}
    return if payload.empty?

    return if payload['from'] == params['device_id']

    return if group_chat?(payload)

    case event
    when 'message'
      WhatsappUnofficial::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    when 'message.edited'
      # WhatsappUnofficial::UpdateMessageService.new(inbox: channel.inbox, params: data).perform
    end
  end

  private

  def group_chat?(payload)
    payload['chat_id'].to_s.end_with?('@g.us')
  end
end
