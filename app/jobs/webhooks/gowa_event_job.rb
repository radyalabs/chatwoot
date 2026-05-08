class Webhooks::GowaEventJob < ApplicationJob
  include WebhookExpiryHandler
  queue_as :default

  ALLOWED_EVENTS = %w[
    message
    message.edited
    message.reaction
  ].freeze

  def perform(params)
    event = params['event']
    return unless ALLOWED_EVENTS.include?(event)

    channel = find_channel_by_phone_number(params)
    return if channel.blank?
    return unless channel_available?(channel)

    payload = params['payload'] || {}
    return if payload.empty?
    return if self_message?(params, payload)

    Rails.logger.info("[GowaEventJob DEBUG] event=#{event} chat_id=#{payload['chat_id']} is_group=#{group_chat?(payload)}")

    if group_chat?(payload)
      handle_group_event(channel, params)
      return
    end

    case event
    when 'message'
      WhatsappUnofficial::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
      send_expired_auto_reply(channel, params) unless account_subscription_active?(channel)
    when 'message.edited'
      # WhatsappUnofficial::UpdateMessageService.new(inbox: channel.inbox, params: data).perform
    end
  rescue StandardError => e
    Rails.logger.error("[GowaEventJob] Unhandled error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
    raise
  end

  private

  def handle_group_event(channel, params)
    GroupChat::LogMessageService.new(channel: channel, params: params).perform
  end

  def find_channel_by_phone_number(params)
    phone_number = params['device_id'].split('@').first
    Channel::WhatsappUnofficial.find_by(phone_number: phone_number)
  end

  def self_message?(params, payload)
    payload['from'] == params['device_id']
  end

  def group_chat?(payload)
    chat_id = payload['chat_id'].to_s
    chat_id.end_with?('@g.us') || chat_id.end_with?('g.us')
  end

  def channel_available?(channel)
    channel.inbox.channel_status
  end
end