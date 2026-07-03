class Captain::Llm::WhatsappReplyContextEnricher
  def initialize(message:)
    @message = message
  end

  def enrich(question)
    return question unless reply_context_enabled?

    replied_text = replied_to_message_text
    return question if replied_text.blank?

    replied_text = replied_text.to_s.strip.truncate(1000)
    question_text = question.to_s

    if question_text.present?
      "User replied to:\n#{replied_text}\n\nUser message:\n#{question_text}"
    else
      "User replied to:\n#{replied_text}"
    end
  rescue StandardError
    question
  end

  private

  def reply_context_enabled?
    return false unless supported_message?

    in_reply_to(content_attributes).present? ||
      in_reply_to_external_id(content_attributes).present? ||
      quoted_text(content_attributes).present?
  end

  def replied_to_message_text
    return nil unless @message.is_a?(Message)

    replied_message = find_replied_message(content_attributes)
    return replied_message.content if replied_message&.content.present?

    attachment_text = attachment_reply_text(replied_message)
    return attachment_text if attachment_text.present?

    quoted_text(content_attributes)
  end

  def attachment_filename(attachment, file_type)
    attachment.file.filename
  rescue StandardError
    file_type
  end

  def supported_message?
    return false unless @message.is_a?(Message)

    message_channel.to_s == 'WhatsappUnofficial'
  end

  def message_channel
    @message.additional_attributes&.[]('channel') || @message.additional_attributes&.[](:channel)
  end

  def content_attributes
    @content_attributes ||= @message.content_attributes || {}
  end

  def in_reply_to(attrs)
    attrs[:in_reply_to] || attrs['in_reply_to']
  end

  def in_reply_to_external_id(attrs)
    attrs[:in_reply_to_external_id] ||
      attrs['in_reply_to_external_id'] ||
      attrs.dig('gowa_reply', 'raw_in_reply_to_external_id') ||
      attrs.dig(:gowa_reply, :raw_in_reply_to_external_id)
  end

  def quoted_text(attrs)
    attrs.dig('gowa_reply', 'quoted_text') || attrs.dig(:gowa_reply, :quoted_text)
  end

  def find_replied_message(attrs)
    if in_reply_to(attrs).present?
      @message.conversation.messages.find_by(id: in_reply_to(attrs))
    elsif in_reply_to_external_id(attrs).present?
      @message.conversation.messages.find_by(source_id: in_reply_to_external_id(attrs))
    end
  end

  def attachment_reply_text(replied_message)
    return nil unless replied_message&.attachments&.any?

    attachment = replied_message.attachments.first
    file_type = attachment.file_type
    "[User replied to a #{file_type}: #{attachment_filename(attachment, file_type)}]"
  end
end
