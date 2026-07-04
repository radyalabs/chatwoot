class Captain::Copilot::Guards::EligibilityGuard
  Result = Struct.new(:code, :failure_reason, :metadata, keyword_init: true) do
    def ok?
      code.nil?
    end
  end

  def initialize(context:, question_payload:, ai_attachments:)
    @context = context
    @question_payload = question_payload
    @ai_attachments = ai_attachments
  end

  def check
    return Result.new(code: :no_active_conversation, metadata: active_conversation_metadata) unless @context.active_conversation

    failure_reason = pre_check_failure_reason
    return Result.new(code: :pre_check_failure, failure_reason: failure_reason) if failure_reason
    return Result.new(code: :no_agent_bot_inbox) unless @context.agent_bot_inbox
    return Result.new(code: :no_ai_agent) unless @context.ai_agent
    return Result.new(code: :bot_not_available) unless @context.bot_available?
    return Result.new(code: :not_meaningful_for_ai, metadata: meaningful_payload_metadata) unless meaningful_for_ai?

    Result.new(code: nil)
  end

  private

  def active_conversation_metadata
    {
      assignee_id: @context.conversation.reload.assignee_id,
      conversation_id: @context.conversation.id
    }
  end

  def pre_check_failure_reason
    return I18n.t('subscriptions.limit_reached') unless @context.subscription
    return I18n.t('subscriptions.limit_reached') unless @context.usage
    return I18n.t('subscriptions.limit_reached') if @context.usage.exceeded_limits?

    nil
  end

  def meaningful_for_ai?
    return true if @question_payload.present?

    @ai_attachments.any? { |attachment| attachment_content_type(attachment).to_s.start_with?('image') }
  end

  def meaningful_payload_metadata
    {
      attachment_types: @ai_attachments.map { |attachment| attachment_content_type(attachment) }
    }
  end

  def attachment_content_type(attachment)
    return attachment[:file_type] || attachment['file_type'] if attachment.is_a?(Hash)

    attachment.file_type
  end
end
