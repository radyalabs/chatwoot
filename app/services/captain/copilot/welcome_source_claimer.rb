class Captain::Copilot::WelcomeSourceClaimer
  def initialize(message)
    @message = message
    @conversation = message.conversation
  end

  def claim?
    return false unless welcome_candidate_message?
    return false unless ai_routable_message?

    return marker_matches_message? if welcome_source_message_id.present?

    source_message = first_incoming_contact_message
    return false unless source_message

    claim_source_message(source_message.id)
    marker_matches_message?
  end

  private

  def welcome_candidate_message?
    @message.sender_type == 'Contact' && @message.incoming? && !@message.private?
  end

  def ai_routable_message?
    AgentBotInbox.where.not(ai_agent_id: nil).exists?(status: :inactive, inbox_id: @message.inbox_id)
  end

  def marker_matches_message?
    welcome_source_message_id == @message.id
  end

  def welcome_source_message_id
    @conversation.reload.captain_welcome_source_message_id
  end

  def first_incoming_contact_message
    @conversation.messages
                 .incoming
                 .where(sender_type: 'Contact', private: false)
                 .reorder(created_at: :asc, id: :asc)
                 .first
  end

  def claim_source_message(source_message_id)
    # rubocop:disable Rails/SkipsModelValidations
    Conversation
      .where(id: @conversation.id, captain_welcome_source_message_id: nil)
      .update_all(captain_welcome_source_message_id: source_message_id)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
