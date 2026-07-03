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

  def first_unprocessed_incoming_message
    incoming_contact_messages_since_processing_boundary
      .reorder(created_at: :asc, id: :asc)
      .first
  end

  def latest_incoming_contact_message
    incoming_contact_messages_since_processing_boundary
      .reorder(created_at: :desc, id: :desc)
      .first
  end

  def processing_boundary_message_id
    [last_ai_reply_id, last_debounced_processed_message_id].compact.max
  end

  def last_debounced_processed_message_id
    value = @conversation.additional_attributes&.dig('last_debounced_processed_message_id')
    return if value.blank?

    value.to_i
  end

  def incoming_contact_messages_since_processing_boundary
    scope = @conversation.messages.incoming.where(sender_type: 'Contact', private: false)
    boundary_id = processing_boundary_message_id
    return scope unless boundary_id

    scope.where('id > ?', boundary_id)
  end

  def last_ai_reply_id
    last_ai_reply&.id
  end
end
