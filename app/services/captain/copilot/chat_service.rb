class Captain::Copilot::ChatService
  include SwitchLocale
  include ResponseFormatChatHelper

  AI_SUPPORTED_ATTACHMENT_TYPES = %w[image].freeze

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
      return unless meaningful_for_ai?

      send_messages
    end
  end

  private

  def meaningful_for_ai?
    return true if @message.content.present?
    return true if @message.attachments.any? { |att| AI_SUPPORTED_ATTACHMENT_TYPES.include?(att.file_type) }

    Rails.logger.info(
      '[ChatService] Skipping AI request — no text or image content | ' \
      "message_id=#{@message.id} | " \
      "attachment_types=#{@message.attachments.map(&:file_type)}"
    )
    false
  end

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

    @context.conversation.messages.incoming.where(private: false).count == 1
  end

  def send_greeting_images(caption: nil)
    greeting_config = @context.ai_agent.flow_data&.dig('greeting_config') || {}
    images = greeting_config['images'] || []
    images = [greeting_config['image']] if images.empty? && greeting_config['image'].present?

    return false if images.empty?

    Rails.logger.info "[BOT] Sending #{images.count} greeting image(s) for conversation #{@context.conversation.id}"

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
    Rails.logger.info "[BOT] Greeting image #{index + 1} sent as message #{message.id}"
  rescue StandardError => e
    Rails.logger.error "[BOT] Failed to send greeting image #{index}: #{e.message}"
  end

  MAX_GREETING_IMAGE_SIZE = 10.megabytes

  def attach_base64_image(message, data_url, attrs, index)
    matches = data_url.match(%r{\Adata:(image/\w+);base64,(.+)\z}m)
    return unless matches

    content_type = matches[1]
    decoded = Base64.decode64(matches[2])

    if decoded.bytesize > MAX_GREETING_IMAGE_SIZE
      Rails.logger.warn "[BOT] Greeting image #{index} exceeds size limit (#{decoded.bytesize} bytes), skipping"
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
      Rails.logger.warn "[BOT] Greeting blob #{blob.filename} exceeds size limit (#{blob.byte_size} bytes), skipping"
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

  def send_reply(response, additional_attributes: {})
    message_content = response[:is_handover] ? handover_processing(response[:response]) : response[:response]

    end_state_processing(response) unless response[:is_handover] || response[:is_failure]

    conversion_processing(response)

    message_created(message_content, additional_attributes.except(:reservation_details))
    send_log_reply(is_handover: response[:is_handover])
  rescue StandardError => e
    Rails.logger.error("Failed to save AI reply: #{e.message}")
  end

  def send_reply_failure(reason)
    Rails.logger.warn("Bot failure: #{reason}")
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
    Rails.logger.info "[BOT] Conversation #{@context.conversation.id} marked as converted (domain change detected)."
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
      status: 0
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
        idx + 1
      )
    end
  end
end
