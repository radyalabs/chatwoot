class Webhooks::WhatsappUnofficialEventsJob < ApplicationJob
  include WebhookExpiryHandler

  queue_as :default

  ALLOWED_EVENTS = %w[
    message
    message.edited
  ].freeze

  def perform(params = {})
    return unless ALLOWED_EVENTS.include?(params['event'])

    channel = find_channel_by_phone_number(params)
    return if channel.blank?
    return if should_skip_processing?(params, channel)
    return unless channel_available?(channel)

    case channel.provider
    when 'gowa'
      WhatsappUnofficial::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
      send_expired_auto_reply(channel, params) unless account_subscription_active?(channel)
    when 'waha'
      # TODO: Implement WhatsappUnofficial::IncomingMessageService
      Rails.logger.info 'WhatsappUnofficial::IncomingMessageService not implemented for waha'
    end
  rescue StandardError => e
    Rails.logger.error("[WhatsappUnofficialEventsJob] Unhandled error processing event: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
    raise
  end

  private

  def find_channel_by_phone_number(params)
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
end
