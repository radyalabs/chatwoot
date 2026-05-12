class Webhooks::GowaEventJob < ApplicationJob
  include WebhookExpiryHandler

  queue_as :default
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  ALLOWED_EVENTS = %w[
    message
    message.edited
  ].freeze

  def perform(params)
    event = params['event']
    return unless ALLOWED_EVENTS.include?(event)
    return if should_skip_processing?(params)

    channel = find_channel(params)
    return if channel.blank?

    with_lock(lock_key(params)) do
      process_event(params, event, channel)
    end
  end

  private

  def process_event(params, event, channel)
    Rails.logger.info "Processing WhatsApp Go event: #{params.inspect}"
    return unless channel_available?(channel)

    case event
    when 'message'
      WhatsappUnofficial::IncomingMessageService.new(inbox: channel.inbox, params: params).perform

      message = channel.inbox.messages.find_by(
        source_id: params.dig('payload', 'id')
      )
      if message
        WhatsappUnofficial::MarkMessageReadService.new(
          channel: channel,
          message: message
        ).perform
      end
    when 'message.edited'
      # WhatsappUnofficial::UpdateMessageService.new(inbox: channel.inbox, params: data).perform
    end
  end

  def find_channel(params)
    phone_number = params['device_id'].split('@').first
    Channel::WhatsappUnofficial.find_by(phone_number: phone_number)
  end

  def should_skip_processing?(params)
    payload = params['payload'] || {}
    return true if payload.empty?
    return true if payload['from'] == params['device_id']
    return true if group_chat?(payload)

    false
  end

  def group_chat?(payload)
    payload['chat_id'].to_s.end_with?('@g.us')
  end

  def channel_available?(channel)
    channel.inbox.channel_status
  end

  def lock_key(params)
    format(
      ::Redis::Alfred::GOWA_MESSAGE_MUTEX,
      device_id: params['device_id'],
      sender_id: params.dig('payload', 'from')
    )
  end
end
