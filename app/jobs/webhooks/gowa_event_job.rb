class Webhooks::GowaEventJob < ApplicationJob
  queue_as :default

  ALLOWED_EVENTS = %w[
    message
    message.edited
  ].freeze

  def perform(params) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    event = params['event']
    return unless ALLOWED_EVENTS.include?(event)
    return if should_skip_processing?(params)

    channel = find_channel_by_phone_number(params)
    return if channel.blank?
    return unless channel_available?(channel)

    case event
    when 'message'
      WhatsappUnofficial::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    when 'message.edited'
      # WhatsappUnofficial::UpdateMessageService.new(inbox: channel.inbox, params: data).perform
    end
  rescue StandardError => e
    Rails.logger.error("[GowaEventJob] Unhandled error processing event: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
    raise
  end

  private

  def find_channel_by_phone_number(params)
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
end
