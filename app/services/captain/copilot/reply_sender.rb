class Captain::Copilot::ReplySender
  LOG_PREFIX = '[Captain::Copilot::ReplySender]'.freeze

  def initialize(context, state_handler: nil)
    @context = context
    @state_handler = state_handler || Captain::Copilot::State::ConversationStateHandler.new(context)
  end

  def send_reply(response, additional_attributes: {})
    message_content = response[:is_handover] ? @state_handler.process_handover(response[:response]) : response[:response]

    @state_handler.process_end_state(response) unless response[:is_handover] || response[:is_failure]
    @state_handler.process_conversion(response)

    Captain::Copilot::ReplyDispatcher
      .new(@context)
      .perform(
        content: message_content,
        additional_attributes: additional_attributes.except(:reservation_details)
      )

    log_reply(is_handover: response[:is_handover])
  rescue StandardError => e
    Rails.logger.error "#{LOG_PREFIX} ai_reply_save_failed | conversation_id=#{@context.conversation.id} | error_class=#{e.class.name}"
  end

  def send_failure(reason, additional_attributes: {})
    Rails.logger.warn "#{LOG_PREFIX} bot_failure_reply | conversation_id=#{@context.conversation.id} | reason=#{reason}"
    response = {
      response: reason,
      is_handover: false,
      is_end_state: false,
      has_domain_change: false,
      is_failure: true
    }
    send_reply(response, additional_attributes: { message_type: 3 }.merge(additional_attributes))
  end

  private

  def log_reply(is_handover: false)
    if is_handover
      Rails.logger.info "#{LOG_PREFIX} handover_completed | conversation_id=#{@context.conversation.id}"
    else
      Rails.logger.info "#{LOG_PREFIX} reply_completed | conversation_id=#{@context.conversation.id}"
    end
  end
end
