class Captain::Copilot::ChatService # rubocop:disable Layout/EndOfLine
  include SwitchLocale
  include ResponseFormatChatHelper

  def initialize(message)
    @message = message
    @context = Captain::Copilot::MessageContext.new(message)
    @current_account = @context.account
  end

  def perform
    switch_locale_using_account_locale do
      return unless @context.active_conversation

      failure_reason = pre_check_failure_reason
      return send_reply_failure(failure_reason) if failure_reason

      return unless @context.agent_bot_inbox
      return unless @context.ai_agent
      return unless @context.bot_available?

      send_messages
    end
  end

  private

  def pre_check_failure_reason
    return I18n.t('subscriptions.limit_reached') unless @context.subscription
    return I18n.t('subscriptions.limit_reached') unless @context.usage

    return I18n.t('subscriptions.limit_reached') if @context.usage.exceeded_limits?

    nil
  end

  def send_messages
    send_message = Captain::Llm::AssistantChatService.new(
      @message,
      @context.conversation,
      @context.ai_agent,
      @current_account.id
    ).perform

    return send_reply_failure(I18n.t('conversations.bot.failure')) unless send_message.success?

    @context.usage.increment_ai_responses
    response = send_message.parsed_response
    parsed = parsed_response(response, is_custom_agent: @context.ai_agent.custom_agent?)

    send_reply(
      parsed,
      additional_attributes: {
        message_type: 1,
        sender_type: 'AiAgent',
        attachments: parsed[:attachments]
      }
    )
  end

  def send_reply(response, additional_attributes: {})
    message_content = response[:is_handover] ? handover_processing(response[:response]) : response[:response]

    end_state_processing(response) unless response[:is_handover]

    conversion_processing(response)

    message_created(message_content, additional_attributes.except(:reservation_details))
    send_log_reply(is_handover: response[:is_handover])
  rescue StandardError => e
    Rails.logger.error("Failed to save AI reply: #{e.message}")
  end

  def send_reply_failure(reason)
    Rails.logger.error("Bot failure: #{reason}")
    response = {
      response: reason,
      is_handover: false,
      is_end_state: false,
      has_domain_change: false
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
    Rails.logger.info "[BOT] Conversation #{@context.conversation.id} marked as converted (domain change detected)."
  end

  def end_state_processing(response)
    attrs = {
      conversation_id: @context.conversation.id,
      inbox_id: @context.inbox_id,
      account_id: @context.account_id,
      ai_agent_id: @context.ai_agent.id
    }

    ::Conversations::AddIdleConversationJob.perform_later(response, attrs)
  end

  def send_log_reply(is_handover: false)
    if is_handover
      Rails.logger.info("Handover completed: Conversation #{@context.conversation.id} assigned to Agent!")
    else
      Rails.logger.info('Bot completed to reply message')
    end
  end

  def find_available_agent
    member_ids = InboxMember.where(inbox_id: @context.inbox_id).pluck(:user_id)
    return nil if member_ids.empty?

    agent_id = Conversation.least_loaded_agent(@context.inbox_id, member_ids)
    agent_id ||= member_ids.sample

    User.find_by(id: agent_id)
  end

  def message_created(content, additional_attributes) # rubocop:disable Metrics/MethodLength
    # Extract image_urls before merging (it's not a Message attribute)
    attachments = additional_attributes&.delete(:attachments)

    attrs = {
      content: content,
      account_id: @context.account_id,
      inbox_id: @context.conversation.inbox_id,
      conversation_id: @context.conversation.id,
      content_type: 0,
      status: 0,
    }

    attrs[:sender_id] = @context.ai_agent&.id

    attrs.merge!(additional_attributes) if additional_attributes.present?

    Message.create!(attrs)

    return if attachments.blank?

    Rails.logger.info "[BOT] Enqueuing #{attachments.count} image(s) for async attach..."

    attachments.each_with_index do |attachment, idx|
      Captain::Copilot::AttachMessageImageJob.perform_later(
        attrs,
        attachment,
        idx + 1,
        content
      )
    end
  end
end
