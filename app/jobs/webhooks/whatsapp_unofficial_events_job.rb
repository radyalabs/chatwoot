class Webhooks::WhatsappUnofficialEventJob < ApplicationJob
  queue_as :default

  ALLOWED_EVENTS = %w[
    message
    message.edited
  ].freeze

  def perform(params = {})
    return if allowed_events(params).present?
    return if should_skip_processing?(params)

    channel = find_channel_by_phone_number(params)
    return if channel.blank?

    case channel.provider
    when 'gowa'
      WhatsappUnofficial::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    when 'waha'
      # TODO: Implement WhatsappUnofficial::IncomingMessageService
      Rails.logger.info 'WhatsappUnofficial::IncomingMessageService not implemented for waha'
    end
  end

  private

  def find_channel_by_phone_number(params)
    phone_number = params['device_id'].split('@').first
    Channel::WhatsappUnofficial.find_by(phone_number: phone_number)
  end

  def should_skip_processing?(params)
    payload = params['payload'] || {}
    return if payload.empty?
    return if payload['from'] == params['device_id']
    return if group_chat?(payload)

    false
  end

  def group_chat?(payload)
    payload['chat_id'].to_s.end_with?('@g.us')
  end

  def allowed_events(params)
    ALLOWED_EVENTS.select { |event| params.key?(event) }
  end
end
