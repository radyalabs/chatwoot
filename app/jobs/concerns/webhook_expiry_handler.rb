module WebhookExpiryHandler
  extend ActiveSupport::Concern

  EXPIRY_MESSAGE_MARKER = 'subscription_expired_auto_reply'.freeze

  def account_subscription_active?(channel)
    channel.inbox.account.active_subscription&.active?
  rescue StandardError => e
    Rails.logger.error("[WebhookExpiryHandler] Error checking subscription status: #{e.message}")
    true
  end

  def send_expired_auto_reply(channel, params)
    account = channel.inbox.account
    sender_phone = params.dig('payload', 'from')&.split('@')&.first
    return if sender_phone.blank?

    contact_inbox = ContactInbox.find_by(source_id: sender_phone, inbox: channel.inbox)
    return unless contact_inbox

    conversation = contact_inbox.contact.conversations
                                .where(inbox: channel.inbox)
                                .order(updated_at: :desc)
                                .first
    return unless conversation
    return if expiry_reply_already_sent?(conversation)

    expiry_message = I18n.t('subscription.expired_auto_reply', locale: account.locale || :id)

    conversation.messages.create!(
      account_id: account.id,
      inbox_id: channel.inbox.id,
      message_type: :outgoing,
      content: expiry_message,
      content_type: :text,
      content_attributes: { message_marker: EXPIRY_MESSAGE_MARKER }
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[WebhookExpiryHandler] Validation error sending auto-reply: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("[WebhookExpiryHandler] Failed to send expired subscription auto-reply: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
  end

  private

  def expiry_reply_already_sent?(conversation)
    conversation.messages.outgoing
                .where("content_attributes->>'message_marker' = ?", EXPIRY_MESSAGE_MARKER)
                .exists?
  end
end
