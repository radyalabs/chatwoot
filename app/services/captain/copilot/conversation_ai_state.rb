class Captain::Copilot::ConversationAiState
  def initialize(conversation)
    @conversation = conversation
  end

  def ai_replied?
    last_ai_reply.present?
  end

  def last_ai_reply
    @last_ai_reply ||= @conversation.messages.where(sender_type: 'AiAgent').order(created_at: :desc, id: :desc).first
  end

  def last_ai_reply_at
    last_ai_reply&.created_at
  end

  def first_unprocessed_incoming_message
    incoming_contact_messages_since_last_ai_reply.first
  end

  def latest_incoming_contact_message
    incoming_contact_messages_since_last_ai_reply
      .order(created_at: :desc, id: :desc)
      .first
  end

  def incoming_contact_messages_since_last_ai_reply
    scope = @conversation.messages.incoming.where(sender_type: 'Contact', private: false)
    return scope unless last_ai_reply_at

    scope.where('created_at > ?', last_ai_reply_at)
  end
end
