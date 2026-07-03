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
    is_welcome = welcome_message?
    parsed = parsed_assistant_response
    return unless parsed

    send_parsed_reply(parsed, is_welcome: is_welcome)
  end

  def parsed_assistant_response
    send_message = Captain::Llm::AssistantChatService.new(
      assistant_message,
      @context.conversation,
      @context.ai_agent,
      @current_account.id,
      attachments: ai_attachments
    ).perform

    unless send_message.success?
      send_reply_failure(I18n.t('conversations.bot.failure'))
      return
    end

    @context.usage.increment_ai_responses
    parsed_response(send_message.parsed_response, is_custom_agent: @context.ai_agent.custom_agent?)
  end

  def send_parsed_reply(parsed, is_welcome:)
    return send_reply(parsed, additional_attributes: reply_attributes(parsed)) unless is_welcome
    return if send_greeting_images(caption: parsed[:response])

    send_reply(parsed, additional_attributes: reply_attributes(parsed))
  end

  def reply_attributes(parsed)
    {
      message_type: 1,
      sender_type: 'AiAgent',
      attachments: parsed[:attachments]
    }
  end

  def welcome_message?
    greeting_config = @context.ai_agent&.display_flow_data&.dig('greeting_config')
    return false unless greeting_config&.dig('enabled')

    !conversation_ai_state.ai_replied?
  end

  def conversation_ai_state
    @conversation_ai_state ||= Captain::Copilot::ConversationAiState.new(@context.conversation)
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

  def send_greeting_images(caption: nil)
    Captain::Copilot::GreetingImageSender
      .new(@context)
      .perform(caption: caption)
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
    message_content = response[:is_handover] ? conversation_state_handler.process_handover(response[:response]) : response[:response]

    conversation_state_handler.process_end_state(response) unless response[:is_handover] || response[:is_failure]

    conversation_state_handler.process_conversion(response)

    Captain::Copilot::ReplyDispatcher
      .new(@context)
      .perform(
        content: message_content,
        additional_attributes: additional_attributes.except(:reservation_details)
      )

    send_log_reply(is_handover: response[:is_handover])
  rescue StandardError => e
    Rails.logger.error "#{LOG_PREFIX} ai_reply_save_failed | conversation_id=#{@context.conversation.id} | error_class=#{e.class.name}"
  end

  def send_reply_failure(reason)
    Rails.logger.warn "#{LOG_PREFIX} bot_failure_reply | conversation_id=#{@context.conversation.id} | reason=#{reason}"
    response = {
      response: reason,
      is_handover: false,
      is_end_state: false,
      has_domain_change: false,
      is_failure: true
    }
    send_reply(response, additional_attributes: { message_type: 3 })
  end

  def conversation_state_handler
    @conversation_state_handler ||= Captain::Copilot::ConversationStateHandler.new(@context)
  end

  def send_log_reply(is_handover: false)
    if is_handover
      Rails.logger.info "#{LOG_PREFIX} handover_completed | conversation_id=#{@context.conversation.id}"
    else
      Rails.logger.info "#{LOG_PREFIX} reply_completed | conversation_id=#{@context.conversation.id}"
    end
  end
end
