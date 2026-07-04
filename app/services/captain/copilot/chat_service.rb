class Captain::Copilot::ChatService
  include SwitchLocale
  include ResponseFormatChatHelper

  AI_SUPPORTED_ATTACHMENT_TYPES = %w[image].freeze
  LOG_PREFIX = '[Captain::Copilot::ChatService]'.freeze

  def initialize(message, combined_question: nil, attachments: nil)
    @message = message
    @context = Captain::Copilot::MessageContext.new(message)
    @current_account = @context.account
    @combined_question = combined_question
    @combined_text = combined_question
    @attachments = attachments || []
  end

  def perform
    switch_locale_using_account_locale do
      eligibility = eligibility_guard.check
      return handle_ineligible_request(eligibility) unless eligibility.ok?

      return if group_message_without_mention?

      conversation_state_handler.clear_pending_idle_conversation
      send_messages
    end
  end

  private

  def eligibility_guard
    Captain::Copilot::EligibilityGuard.new(
      context: @context,
      question_payload: question_payload,
      ai_attachments: ai_attachments
    )
  end

  def handle_ineligible_request(result)
    Captain::Copilot::EligibilityGuardLogger
      .new(@message, @context)
      .log(result)

    return send_reply_failure(result.failure_reason) if result.code == :pre_check_failure

    nil
  end

  def group_message_without_mention?
    policy = Captain::Copilot::GroupMentionPolicy.new(@message, inbox: @context.inbox)
    return false unless policy.skip_reason == :missing_bot_mention

    Rails.logger.info "#{LOG_PREFIX} skipped_group_message_without_bot_mention | conversation_id=#{@context.conversation.id}"
    true
  end

  def send_messages
    parsed = parsed_assistant_response
    return unless parsed

    send_reply(parsed, additional_attributes: reply_attributes(parsed))
  end

  def parsed_assistant_response
    send_message = Captain::Llm::AssistantChatService.new(
      context: {
        message: assistant_message,
        conversation: @context.conversation,
        ai_agent: @context.ai_agent,
        account_id: @current_account.id
      },
      attachments: ai_attachments,
      intent: :completion
    ).perform

    unless send_message.success?
      send_reply_failure(I18n.t('conversations.bot.failure'))
      return
    end

    @context.usage.increment_ai_responses
    parsed_response(send_message.parsed_response, is_custom_agent: @context.ai_agent.custom_agent?)
  end

  def reply_attributes(parsed)
    {
      message_type: 1,
      sender_type: 'AiAgent',
      attachments: parsed[:attachments]
    }
  end

  def assistant_message
    @combined_question.presence || @message
  end

  def question_payload
    return @combined_question if @combined_question.is_a?(String)

    @message.content
  end

  def ai_attachments
    return @attachments if @attachments.present?

    @message.attachments
            .includes(file_attachment: :blob)
            .select { |att| att.file.attached? }
            .map do |att|
      {
        key: att.file.key,
        file_type: att.file.content_type,
        filename: att.file.filename.to_s,
        url: att.download_url
      }
    end
  end

  def enrich_with_group_context
    return @combined_text unless GroupContextService.new(@message, @combined_text).group_summary_request?

    enriched = GroupContextService.new(@message, @combined_text).enrich_message
    return @combined_text if enriched == check_original_text

    Rails.logger.info "#{LOG_PREFIX} group_context_injected | message_id=#{@message.id}"
    enriched
  end

  def check_original_text
    @combined_text.presence || @message.content.to_s
  end

  def send_reply(response, additional_attributes: {})
    reply_sender.send_reply(response, additional_attributes: additional_attributes)
  end

  def send_reply_failure(reason)
    reply_sender.send_failure(reason)
  end

  def conversation_state_handler
    @conversation_state_handler ||= Captain::Copilot::ConversationStateHandler.new(@context)
  end

  def reply_sender
    @reply_sender ||= Captain::Copilot::ReplySender.new(@context, state_handler: conversation_state_handler)
  end
end
