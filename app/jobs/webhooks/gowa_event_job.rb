class Webhooks::GowaEventJob < ApplicationJob
  queue_as :default

  ALLOWED_EVENTS = %w[
    message
    message.edited
  ].freeze

  def perform(params)
    event = params['event']
    return unless ALLOWED_EVENTS.include?(event)
    return if should_skip_processing?(params)

    channel = find_channel_by_phone_number(params)
    return if channel.blank?
    return unless channel_available?(channel)

    case event
    when 'message'
      WhatsappUnofficial::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
      send_expired_auto_reply(channel, params) unless account_subscription_active?(channel)
    when 'message.edited'
      # WhatsappUnofficial::UpdateMessageService.new(inbox: channel.inbox, params: data).perform
    end
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

  def account_subscription_active?(channel)
    channel.inbox.account.active_subscription&.active?
  end

  def send_expired_auto_reply(channel, params)
    account = channel.inbox.account
    sender_phone = params.dig('payload', 'from')&.split('@')&.first
    contact_inbox = ContactInbox.find_by(source_id: sender_phone, inbox: channel.inbox)
    return unless contact_inbox

    conversation = contact_inbox.contact.conversations.where(inbox: channel.inbox).order(updated_at: :desc).first
    return unless conversation

    expiry_message = I18n.t('subscription.expired_auto_reply', locale: account.locale || :id)
    return if conversation.messages.outgoing.where(content: expiry_message).exists?

    conversation.messages.create!(
      account_id: account.id,
      inbox_id: channel.inbox.id,
      message_type: :outgoing,
      content: expiry_message,
      content_type: :text
    )
  rescue StandardError => e
    Rails.logger.error "Failed to send expired subscription auto-reply: #{e.message}"
  end
end
