class Captain::Copilot::WelcomeMessageService
  include SwitchLocale
  include ResponseFormatChatHelper

  LOG_PREFIX = '[Captain::Copilot::WelcomeMessageService]'.freeze

  def initialize(message)
    @message = message
    @context = Captain::Copilot::MessageContext.new(message)
    @current_account = @context.account
  end

  def perform
    switch_locale_using_account_locale do
      return if group_conversation?

      eligibility = eligibility_guard.check
      return handle_ineligible_request(eligibility) unless eligibility.ok?

      conversation_state_handler.clear_pending_idle_conversation
      send_welcome_message
    end
  end

  private

  def eligibility_guard
    Captain::Copilot::EligibilityGuard.new(
      context: @context,
      question_payload: @message.content,
      ai_attachments: ai_attachments
    )
  end

  def handle_ineligible_request(result)
    Captain::Copilot::EligibilityGuardLogger
      .new(@message, @context)
      .log(result)

    return reply_sender.send_failure(result.failure_reason, additional_attributes: welcome_reply_attributes) if result.code == :pre_check_failure

    nil
  end

  def send_welcome_message
    parsed = parsed_assistant_response
    return unless parsed
    return if greeting_image_sender.perform(caption: parsed[:response], additional_attributes: welcome_reply_attributes)

    reply_sender.send_reply(parsed, additional_attributes: reply_attributes(parsed).merge(additional_attributes: welcome_reply_attributes))
  end

  def parsed_assistant_response
    assistant_response = Captain::Llm::AssistantChatService.new(
      context: {
        message: @message,
        conversation: @context.conversation,
        ai_agent: @context.ai_agent,
        account_id: @current_account.id
      },
      attachments: ai_attachments,
      intent: :welcome
    ).perform

    unless assistant_response.success?
      reply_sender.send_failure(I18n.t('conversations.bot.failure'), additional_attributes: welcome_reply_attributes)
      return
    end

    @context.usage.increment_ai_responses
    update_processing_watermark
    parsed_response(assistant_response.parsed_response, is_custom_agent: @context.ai_agent.custom_agent?)
  end

  def reply_attributes(parsed)
    {
      message_type: 1,
      sender_type: 'AiAgent',
      attachments: parsed[:attachments]
    }
  end

  def welcome_reply_attributes
    { 'welcome_source_message_id' => @message.id }
  end

  def ai_attachments
    @ai_attachments ||= @message.attachments
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

  def group_conversation?
    @context.conversation.additional_attributes&.dig('group_chat_id').present?
  end

  def update_processing_watermark
    attrs = @context.conversation.additional_attributes.is_a?(Hash) ? @context.conversation.additional_attributes.deep_dup : {}
    current_watermark = attrs['last_debounced_processed_message_id'].to_i
    attrs['last_debounced_processed_message_id'] = [current_watermark, @message.id.to_i].max
    @context.conversation.update!(additional_attributes: attrs)
  end

  def conversation_state_handler
    @conversation_state_handler ||= Captain::Copilot::ConversationStateHandler.new(@context)
  end

  def reply_sender
    @reply_sender ||= Captain::Copilot::ReplySender.new(@context, state_handler: conversation_state_handler)
  end

  def greeting_image_sender
    @greeting_image_sender ||= Captain::Copilot::GreetingImageSender.new(@context)
  end
end
