class Captain::Copilot::Policies::GroupMentionPolicy
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
    phone = bot_phone
    return false if phone.blank?

    explicit_phone_mention?(phone) ||
      mentioned_jids_include?(phone) ||
      reply_context_mentions_bot?
  end

  def bot_phone
    channel = @inbox.channel
    return nil unless channel.respond_to?(:bot_jid)

    channel.phone_number.to_s.gsub(/\D/, '')
  end

  def explicit_phone_mention?(phone)
    @message.content.to_s.downcase.include?("@#{phone}")
  end

  def mentioned_jids_include?(phone)
    mentioned_jids = @message.content_attributes&.dig('mentioned_jids') || []
    mentioned_jids.any? { |jid| jid.include?(phone) }
  end

  def reply_context_mentions_bot?
    reply_context = @message.content_attributes&.dig('gowa_reply', 'raw_in_reply_to_external_id')
    reply_context.present? && bot_message_replied_to?
  end

  def bot_message_replied_to?
    reply_id = @message.content_attributes&.dig('in_reply_to_external_id') ||
               @message.content_attributes&.dig('gowa_reply', 'raw_in_reply_to_external_id')
    return false unless reply_id

    @message.conversation.messages
            .where.not(sender_type: 'Contact')
            .exists?(source_id: reply_id)
  end
end
