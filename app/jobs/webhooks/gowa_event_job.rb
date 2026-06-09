class Webhooks::GowaEventJob < MutexApplicationJob
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

    channel = find_channel(params)
    return if channel.blank?
    return if should_skip_processing?(params, channel)

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

      send_expired_auto_reply(channel, params) unless account_subscription_active?(channel)
    when 'message.edited'
      # WhatsappUnofficial::UpdateMessageService.new(inbox: channel.inbox, params: data).perform
    end
  end

  def find_channel(params)
    phone_number = params['device_id'].split('@').first
    Channel::WhatsappUnofficial.find_by(phone_number: phone_number)
  end

  def should_skip_processing?(params, channel)
    payload = params['payload'] || {}
    return true if payload.empty?
    return true if self_message?(payload, params, channel)

    if group_chat?(payload)
      return true unless channel.group_enabled?
      return true unless group_in_monitored_list?(payload, channel)
    end

    false
  end

  def self_message?(payload, params, channel)
    return true if payload['from'] == params['device_id']

    phone = channel.phone_number.to_s.gsub(/\D/, '')
    sender = payload['from'].to_s.split('@').first
    sender == phone
  end

  def group_chat?(payload)
    payload['chat_id'].to_s.end_with?('@g.us')
  end

  def group_in_monitored_list?(payload, channel)
    monitored = channel.monitored_groups
    return true if monitored.blank?

    monitored.any? { |g| g['jid'] == payload['chat_id'] }
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
