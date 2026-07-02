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
      unless @context.active_conversation
        Rails.logger.info "#{LOG_PREFIX} skipped_no_active_conversation | message_id=#{@message.id} | conversation_id=#{@context.conversation.id} | assignee_id=#{@context.conversation.reload.assignee_id}"
        return
      end

      failure_reason = pre_check_failure_reason
      if failure_reason
        Rails.logger.info "#{LOG_PREFIX} skipped_pre_check_failure | message_id=#{@message.id} | reason=#{failure_reason}"
        return send_reply_failure(failure_reason)
      end

      unless @context.agent_bot_inbox
        Rails.logger.warn "#{LOG_PREFIX} skipped_no_agent_bot_inbox | message_id=#{@message.id} | inbox_id=#{@context.inbox_id}"
        return
      end

      unless @context.ai_agent
        Rails.logger.warn "#{LOG_PREFIX} skipped_no_ai_agent | message_id=#{@message.id}"
        return
      end

      unless @context.bot_available?
        Rails.logger.info "#{LOG_PREFIX} skipped_bot_not_available | message_id=#{@message.id}"
        return
      end

      unless meaningful_for_ai?
        Rails.logger.info "#{LOG_PREFIX} skipped_not_meaningful_for_ai | message_id=#{@message.id}"
        return
      end

      return if group_message_without_mention?

      clear_pending_idle_conversation
      send_messages
    end
  end

  private

  def meaningful_for_ai?
    return true if question_payload.present?
    return true if ai_attachments.any? { |att| attachment_type(att).to_s.start_with?('image') }

    Rails.logger.info(
      "#{LOG_PREFIX} skipped_no_text_or_image_content | " \
      "message_id=#{@message.id} | " \
      "attachment_types=#{ai_attachments.map { |att| attachment_type(att) }}"
    )
    false
  end

  def group_message_without_mention?
    policy = Captain::Copilot::GroupMentionPolicy.new(@message, inbox: @context.inbox)
    return false unless policy.skip_reason == :missing_bot_mention

    Rails.logger.info "#{LOG_PREFIX} skipped_group_message_without_bot_mention | conversation_id=#{@context.conversation.id}"
    true
  end

  def pre_check_failure_reason
    return I18n.t('subscriptions.limit_reached') unless @context.subscription
    return I18n.t('subscriptions.limit_reached') unless @context.usage

    return I18n.t('subscriptions.limit_reached') if @context.usage.exceeded_limits?

    nil
  end

  def send_messages
    is_welcome = welcome_message?

    send_message = Captain::Llm::AssistantChatService.new(
      assistant_message,
      @context.conversation,
      @context.ai_agent,
      @current_account.id,
      attachments: ai_attachments
    ).perform

    return send_reply_failure(I18n.t('conversations.bot.failure')) unless send_message.success?

    @context.usage.increment_ai_responses
    response = send_message.parsed_response
    parsed = parsed_response(response, is_custom_agent: @context.ai_agent.custom_agent?)

    if is_welcome
      sent = send_greeting_images(caption: parsed[:response])

      unless sent
        send_reply(
          parsed,
          additional_attributes: {
            message_type: 1,
            sender_type: 'AiAgent',
            attachments: parsed[:attachments]
          }
        )
      end
    else
      send_reply(
        parsed,
        additional_attributes: {
          message_type: 1,
          sender_type: 'AiAgent',
          attachments: parsed[:attachments]
        }
      )
    end
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

  def attachment_type(attachment)
    return attachment[:file_type] || attachment['file_type'] if attachment.is_a?(Hash)

    attachment.file_type
  end

  def send_greeting_images(caption: nil)
    Captain::Copilot::GreetingImageSender
      .new(@context, log_prefix: LOG_PREFIX)
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
    message_content = response[:is_handover] ? handover_processing(response[:response]) : response[:response]

    end_state_processing(response) unless response[:is_handover] || response[:is_failure]

    conversion_processing(response)

    Captain::Copilot::ReplyDispatcher
      .new(@context, log_prefix: LOG_PREFIX)
      .perform(
        content: message_content,
        additional_attributes: additional_attributes.except(:reservation_details)
      )

    send_log_reply(is_handover: response[:is_handover])
  rescue StandardError => e
    Rails.logger.error "#{LOG_PREFIX} ai_reply_save_failed | conversation_id=#{@context.conversation.id} | error=#{e.message}"
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

  def handover_processing(content)
    agent_available = find_available_agent

    @context.conversation.update!(assignee_id: agent_available.id, is_reminded: false, is_handover_reminded: true) if agent_available
    agent_available ? content : I18n.t('conversations.bot.not_available_agent')
  end

  def conversion_processing(response)
    return if @context.conversation.is_convert?

    return unless response[:has_domain_change]

    @context.conversation.update(is_convert: true)
    Rails.logger.info "#{LOG_PREFIX} conversation_marked_converted | conversation_id=#{@context.conversation.id}"
  end

  def end_state_processing(response)
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

  def send_log_reply(is_handover: false)
    if is_handover
      Rails.logger.info "#{LOG_PREFIX} handover_completed | conversation_id=#{@context.conversation.id}"
    else
      Rails.logger.info "#{LOG_PREFIX} reply_completed | conversation_id=#{@context.conversation.id}"
    end
  end

  def find_available_agent
    member_ids = InboxMember.where(inbox_id: @context.inbox_id).pluck(:user_id)
    return nil if member_ids.empty?

    agent_id = Conversation.least_loaded_agent(@context.inbox_id, member_ids)
    agent_id ||= member_ids.sample

    User.find_by(id: agent_id)
  end
end
