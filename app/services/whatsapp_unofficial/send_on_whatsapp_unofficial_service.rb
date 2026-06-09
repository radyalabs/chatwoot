class WhatsappUnofficial::SendOnWhatsappUnofficialService < Base::SendOnChannelService
  def channel_class
    Channel::WhatsappUnofficial
  end

  def perform_reply
    response = channel.send_message(**message_params)

    if response.is_a?(Hash)
      message_id = response['message_id'] || response.dig('results', 'message_id')
      message.update!(source_id: message_id) if message_id.present?
    end
  rescue StandardError => e
    Rails.logger.error "WhatsappUnofficial::SendOnWhatsappUnofficialService: Error: #{e.message}"
    message.update!(status: :failed, external_error: e.message)
  end

  def message_params
    {
      phone_number: reply_phone_number,
      content: message.content,
      attachments: attachments,
      link: link(message)
    }
  end

  def reply_phone_number
    group_chat_id = message.conversation.additional_attributes&.dig('group_chat_id')
    return group_chat_id if group_chat_id.present?

    contact_inbox.source_id
  end

  def attachments
    message.attachments.filter_map do |attachment|
      next unless attachment.file.attached?

      file_data = attachment.file.download
      file_data = file_data.b if file_data.respond_to?(:b)
      {
        filename: attachment.file.filename.to_s.encode('UTF-8'),
        content_type: attachment.file.content_type.to_s.encode('UTF-8'),
        io: StringIO.new(file_data),
        file_type: attachment.file_type,
        download_url: attachment.download_url
      }
    end.compact
  end

  def link(message)
    # return message.content_attributes['link'] if message.content_attributes&.dig('link').present?

    return nil if message.content.blank?

    message.content[%r{https?://[^\s]+}]
  end

  def inbox
    @inbox ||= message.inbox
  end

  def channel
    @channel ||= inbox.channel
  end

  def outgoing_message?
    message.outgoing? || message.template?
  end

  private

  def extract_reply_message_id
    return nil unless message.is_a?(Message)

    last_incoming = message.conversation.messages
                           .where(message_type: :incoming)
                           .where('created_at <= ?', message.created_at)
                           .where.not(source_id: nil)
                           .order(:created_at)
                           .last

    last_incoming&.source_id
  end
end
