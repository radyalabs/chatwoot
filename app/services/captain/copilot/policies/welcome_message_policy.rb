class Captain::Copilot::Policies::WelcomeMessagePolicy
  def initialize(message)
    @message = message
    @context = Captain::Copilot::State::MessageContext.new(message)
  end

  def eligible?
    return false unless welcome_candidate_message?
    return false if group_conversation?
    return false unless greeting_enabled?
    return false unless welcome_source_message?

    !conversation_ai_state.ai_replied?
  end

  private

  def welcome_candidate_message?
    @message.sender_type == 'Contact' && @message.incoming? && !@message.private?
  end

  def group_conversation?
    @context.conversation.additional_attributes&.dig('group_chat_id').present?
  end

  def greeting_enabled?
    @context.ai_agent&.display_flow_data&.dig('greeting_config', 'enabled') == true
  end

  def welcome_source_message?
    @context.conversation.reload.captain_welcome_source_message_id == @message.id
  end

  def conversation_ai_state
    @conversation_ai_state ||= Captain::Copilot::State::ConversationAiState.new(@context.conversation)
  end
end
