class Captain::Copilot::EligibilityGuardLogger
  def initialize(message, context, log_prefix:)
    @message = message
    @context = context
    @log_prefix = log_prefix
  end

  def log(result)
    case result.code
    when :no_active_conversation then log_no_active_conversation(result)
    when :pre_check_failure then log_pre_check_failure(result)
    when :no_agent_bot_inbox then log_no_agent_bot_inbox
    when :no_ai_agent then log_no_ai_agent
    when :bot_not_available then log_bot_not_available
    when :not_meaningful_for_ai then log_not_meaningful_for_ai(result)
    end
  end

  private

  def log_no_active_conversation(result)
    Rails.logger.info(
      "#{@log_prefix} skipped_no_active_conversation | " \
      "message_id=#{@message.id} | " \
      "conversation_id=#{result.metadata[:conversation_id]} | " \
      "assignee_id=#{result.metadata[:assignee_id]}"
    )
  end

  def log_pre_check_failure(result)
    Rails.logger.info "#{@log_prefix} skipped_pre_check_failure | message_id=#{@message.id} | reason=#{result.failure_reason}"
  end

  def log_no_agent_bot_inbox
    Rails.logger.warn "#{@log_prefix} skipped_no_agent_bot_inbox | message_id=#{@message.id} | inbox_id=#{@context.inbox_id}"
  end

  def log_no_ai_agent
    Rails.logger.warn "#{@log_prefix} skipped_no_ai_agent | message_id=#{@message.id}"
  end

  def log_bot_not_available
    Rails.logger.info "#{@log_prefix} skipped_bot_not_available | message_id=#{@message.id}"
  end

  def log_not_meaningful_for_ai(result)
    Rails.logger.info "#{@log_prefix} skipped_not_meaningful_for_ai | message_id=#{@message.id}"
    Rails.logger.info(
      "#{@log_prefix} skipped_no_text_or_image_content | " \
      "message_id=#{@message.id} | " \
      "attachment_types=#{result.metadata[:attachment_types]}"
    )
  end
end
