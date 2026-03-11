# frozen_string_literal: true

class WelcomeMessageListener < BaseListener
  def conversation_created(event)
    # Intentionally no-op.
    # We want welcome to be triggered when the user starts the conversation by sending
    # the first incoming message, not simply when the conversation record is created.
    conversation = extract_conversation_and_account(event)[0]
    Rails.logger.debug("[WelcomeMessageListener] conversation.created observed conversation_id=#{conversation&.id}")
  rescue StandardError => e
    Rails.logger.error("[WelcomeMessageListener] Failed: #{e.class}: #{e.message}")
  end

  def message_created(event)
    message = extract_message_and_account(event)[0]

    return if message.blank? || message.private?

    conversation = message.conversation
    return if conversation.blank?

    unless welcome_enabled?
      Rails.logger.warn(
        "[WelcomeMessageListener] Skipping (disabled) conversation_id=#{conversation.id} set JANGKAU_WELCOME_ENABLED=1"
      )
      return
    end

    # Ensure the main AI completion answer is posted first.
    # We enqueue welcome only after the first outgoing AiAgent message is created.
    return unless message.outgoing? && message.sender_type == 'AiAgent'

    if message.additional_attributes.to_h.dig('jangkau', 'welcome') || message.additional_attributes.to_h['jangkau_welcome']
      Rails.logger.debug(
        "[WelcomeMessageListener] Skipping (welcome marker) conversation_id=#{conversation.id} message_id=#{message.id}"
      )
      return
    end

    custom_attrs = conversation.custom_attributes || {}
    if custom_attrs['jangkau_welcome_sent']
      Rails.logger.debug(
        "[WelcomeMessageListener] Skipping (already sent) conversation_id=#{conversation.id} message_id=#{message.id}"
      )
      return
    end

    incoming_count = conversation.messages.incoming.where(private: false).count
    unless incoming_count == 1
      Rails.logger.debug(
        "[WelcomeMessageListener] Skipping (incoming_count!=1) conversation_id=#{conversation.id} message_id=#{message.id} incoming_count=#{incoming_count}"
      )
      return
    end

    first_ai_outgoing_id = conversation.messages.outgoing.where(private: false, sender_type: 'AiAgent').reorder(:created_at).limit(1).pluck(:id).first
    unless first_ai_outgoing_id == message.id
      Rails.logger.debug(
        "[WelcomeMessageListener] Skipping (not first AiAgent outgoing) conversation_id=#{conversation.id} message_id=#{message.id} first_ai_outgoing_id=#{first_ai_outgoing_id}"
      )
      return
    end

    Rails.logger.info(
      "[WelcomeMessageListener] Enqueue welcome job (after first AiAgent reply) conversation_id=#{conversation.id} inbox_id=#{conversation.inbox_id} message_id=#{message.id}"
    )

    Conversations::WelcomeMessageJob.set(wait: 1.second).perform_later(conversation.id)
  rescue StandardError => e
    Rails.logger.error("[WelcomeMessageListener] Failed in message_created: #{e.class}: #{e.message}")
  end

  private

  def welcome_enabled?
    raw = ENV.fetch('JANGKAU_WELCOME_ENABLED', nil)
    return false if raw.blank?

    %w[1 true yes y on].include?(raw.to_s.strip.downcase)
  end
end
