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
    return false unless group_conversation?

    unless bot_mentioned?
      Rails.logger.info "#{LOG_PREFIX} skipped_group_message_without_bot_mention | conversation_id=#{@context.conversation.id}"
      return true
    end

    false
  end

  def group_conversation?
    @message.conversation.additional_attributes&.dig('group_chat_id').present?
  end

  def bot_mentioned?
    content_body = @message.content.to_s.downcase
    channel = @context.inbox.channel
    return false unless channel.respond_to?(:bot_jid)

    bot_phone = channel.phone_number.to_s.gsub(/\D/, '')

    return true if content_body.include?("@#{bot_phone}")

    mentioned = @message.content_attributes&.dig('mentioned_jids') || []
    return true if mentioned.any? { |jid| jid.include?(bot_phone) }

    reply_context = @message.content_attributes&.dig('gowa_reply', 'raw_in_reply_to_external_id')
    return true if reply_context.present? && bot_message_replied_to?

    false
  end

  def bot_message_replied_to?
    reply_id = @message.content_attributes&.dig('in_reply_to_external_id') ||
               @message.content_attributes&.dig('gowa_reply', 'raw_in_reply_to_external_id')
    return false unless reply_id

    bot_messages = @message.conversation.messages
                           .where.not(sender_type: 'Contact')
                           .where(source_id: reply_id)
    bot_messages.any?
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
    greeting_config = @context.ai_agent.flow_data&.dig('greeting_config') || {}
    images = greeting_config['images'] || []
    images = [greeting_config['image']] if images.empty? && greeting_config['image'].present?

    return false if images.empty?

    Rails.logger.info "#{LOG_PREFIX} sending_greeting_images | conversation_id=#{@context.conversation.id} | image_count=#{images.count}"

    attrs = {
      account_id: @context.account_id,
      inbox_id: @context.conversation.inbox_id,
      conversation_id: @context.conversation.id,
      content_type: 0,
      status: 0,
      message_type: 1,
      sender_type: 'AiAgent',
      sender_id: @context.ai_agent.id
    }

    images.each_with_index do |image_ref, idx|
      image_caption = idx.zero? ? caption : nil
      send_greeting_image(image_ref, attrs, idx, caption: image_caption)
    end

    true
  end

  def send_greeting_image(image_ref, attrs, index, caption: nil)
    return unless image_ref.is_a?(String) && image_ref.present?

    message = Message.new(attrs.merge(content: caption.presence || ''))

    if image_ref.start_with?('data:image/')
      attach_base64_image(message, image_ref, attrs, index)
    else
      attach_signed_id_image(message, image_ref)
    end

    message.save!
    Rails.logger.info "#{LOG_PREFIX} greeting_image_sent | conversation_id=#{@context.conversation.id} | image_index=#{index + 1} | message_id=#{message.id}"
  rescue StandardError => e
    Rails.logger.error "#{LOG_PREFIX} greeting_image_send_failed | conversation_id=#{@context.conversation.id} | image_index=#{index + 1} | error=#{e.message}"
  end

  MAX_GREETING_IMAGE_SIZE = 10.megabytes

  def attach_base64_image(message, data_url, attrs, index)
    matches = data_url.match(%r{\Adata:(image/\w+);base64,(.+)\z}m)
    return unless matches

    content_type = matches[1]
    decoded = Base64.decode64(matches[2])

    if decoded.bytesize > MAX_GREETING_IMAGE_SIZE
      Rails.logger.warn "#{LOG_PREFIX} skipped_greeting_image_too_large | image_index=#{index + 1} | image_size_bytes=#{decoded.bytesize} | max_size_bytes=#{MAX_GREETING_IMAGE_SIZE}"
      return
    end

    ext = { 'image/png' => '.png', 'image/gif' => '.gif', 'image/webp' => '.webp' }.fetch(content_type, '.jpg')
    filename = "greeting_#{attrs[:conversation_id]}_#{index}_#{Time.current.to_i}#{ext}"

    message.attachments.build(
      account_id: attrs[:account_id],
      file_type: 'image',
      file: { io: StringIO.new(decoded), filename: filename, content_type: content_type }
    )
  end

  def attach_signed_id_image(message, signed_id)
    blob = ActiveStorage::Blob.find_signed!(signed_id)

    if blob.byte_size > MAX_GREETING_IMAGE_SIZE
      Rails.logger.warn "#{LOG_PREFIX} skipped_greeting_blob_too_large | filename=#{blob.filename} | image_size_bytes=#{blob.byte_size} | max_size_bytes=#{MAX_GREETING_IMAGE_SIZE}"
      return
    end

    binary_data = blob.download
    io = StringIO.new(binary_data)
    io.binmode

    safe_filename = blob.filename.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '_')

    message.attachments.build(
      account_id: message.account_id,
      file_type: 'image',
      file: {
        io: io,
        filename: safe_filename,
        content_type: blob.content_type.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      }
    )
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

    message_created(message_content, additional_attributes.except(:reservation_details))
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

  def message_created(content, additional_attributes)
    attachments = additional_attributes&.delete(:attachments)

    attrs = {
      content: content,
      account_id: @context.account_id,
      inbox_id: @context.conversation.inbox_id,
      conversation_id: @context.conversation.id,
      content_type: 0,
      status: 0
    }

    attrs[:sender_id] = @context.ai_agent&.id

    attrs.merge!(additional_attributes) if additional_attributes.present?

    Message.create!(attrs)

    return if attachments.blank?

    Rails.logger.info "#{LOG_PREFIX} enqueue_async_image_attach | conversation_id=#{@context.conversation.id} | image_count=#{attachments.count}"

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
