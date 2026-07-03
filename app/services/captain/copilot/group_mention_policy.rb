class Captain::Copilot::GroupMentionPolicy
  def initialize(message, inbox:)
    @message = message
    @inbox = inbox
  end

  def skip_reason
    return nil unless group_conversation?
    return :missing_bot_mention unless bot_mentioned?

    nil
  end

  private

  def group_conversation?
    @message.conversation.additional_attributes&.dig('group_chat_id').present?
  end

  def bot_mentioned?
    content_body = @message.content.to_s.downcase
    channel = @inbox.channel
    return false unless channel.respond_to?(:bot_jid)

    bot_phone = channel.phone_number.to_s.gsub(/\D/, '')
    return true if content_body.include?("@#{bot_phone}")

    mentioned = @message.content_attributes&.dig('mentioned_jids') || []
    return true if mentioned.any? { |jid| jid.include?(bot_phone) }

    reply_context = @message.content_attributes&.dig('gowa_reply', 'raw_in_reply_to_external_id')
    return true if reply_context.present? && bot_message_replied_to?

    false
  end

  def bot_message_replied_to?
    reply_id = @message.content_attributes&.dig('in_reply_to_external_id') ||
               @message.content_attributes&.dig('gowa_reply', 'raw_in_reply_to_external_id')
    return false unless reply_id

    @message.conversation.messages
            .where.not(sender_type: 'Contact')
            .where(source_id: reply_id)
            .exists?
  end
end
