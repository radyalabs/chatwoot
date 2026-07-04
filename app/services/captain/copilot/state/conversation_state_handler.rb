class Captain::Copilot::State::ConversationStateHandler
  LOG_PREFIX = '[Captain::Copilot::State::ConversationStateHandler]'.freeze

  def initialize(context)
    @context = context
  end

  def process_handover(content)
    agent_available = find_available_agent

    if agent_available
      @context.conversation.update!(assignee_id: agent_available.id, is_reminded: false, is_handover_reminded: true)
      return content
    end

    I18n.t('conversations.bot.not_available_agent')
  end

  def process_conversion(response)
    return if @context.conversation.is_convert?
    return unless response[:has_domain_change]

    @context.conversation.update(is_convert: true)
    Rails.logger.info "#{LOG_PREFIX} conversation_marked_converted | conversation_id=#{@context.conversation.id}"
  end

  def process_end_state(response)
    return unless @context.ai_agent

    attrs = {
      conversation_id: @context.conversation.id,
      inbox_id: @context.inbox_id,
      account_id: @context.account_id,
      ai_agent_id: @context.ai_agent.id
    }

    ::Conversations::AddIdleConversationJob.perform_later(response, attrs)
  end

  def clear_pending_idle_conversation
    IdleConversation.where(conversation_id: @context.conversation.id, status: :idle).destroy_all
  end

  private

  def find_available_agent
    member_ids = InboxMember.where(inbox_id: @context.inbox_id).pluck(:user_id)
    return nil if member_ids.empty?

    agent_id = Conversation.least_loaded_agent(@context.inbox_id, member_ids)
    agent_id ||= member_ids.sample

    User.find_by(id: agent_id)
  end
end
